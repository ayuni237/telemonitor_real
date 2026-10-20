"""Run the benchmark and the external validation.

    python -m telemonitor.run [--quick] [--tasks haemodynamic glycaemic] [--leads 0 12 36]

1. Development data: the eICU demo, harmonised (eicu.py), quality-controlled.
2. For each task and lead time: nested benchmark (search.run), outer folds by hospital.
3. Final fit of every candidate on all development data (inner search on all of it),
   applied once to the Douala charts: measures as is, with patient-level bootstrap
   intervals, and after updating the intercept (thesis §Risk score).
Every run is recorded in out/runs/<task>_<lead>h_<id>/ (tracking.py): configurations,
code, environment, fold results, every trial, every prediction, final models, summary.
Launching the same run again resumes it; scripts/08_figures.py redraws its figures.
"""
from __future__ import annotations

import argparse
import copy
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd

from . import eicu, metrics as M, objective as O, quality as Q, search as S, validation as V
from .labels import load_thresholds
from .models import tabular as T
from .progress import progress
from .tracking import Run
from .windows import make_samples

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "out"
DEMO = ROOT / "data" / "external" / "eicu-demo-2.0.1"
DOUALA = ROOT / "cohortB_complete.csv"
THRESHOLDS = ROOT / "configs" / "thresholds.yaml"
ALL = ["ordinal_logistic", "pca_logistic", "forest", "catboost", "value_ridge", "value_catboost", "grud", "lstm"]


def development_data():
    if not eicu.verify(DEMO):
        raise SystemExit("eICU demo missing or checksum mismatch: " + str(DEMO))
    d = Q.check(eicu.load_demo(DEMO)).clean
    return d


def douala_data():
    d = Q.check(pd.read_csv(DOUALA, parse_dates=["date"])).clean
    return d.assign(group=d["patient"])


def external(dev, ext, table, task, candidates, bench, cost_cfg, seed=0, recorder: Run | None = None):
    """Fit on all development samples, evaluate once on the external samples.

    With a `recorder`, each candidate is saved as soon as it is done (measures,
    Douala predictions, fitted model, trials of the final search), and candidates
    already recorded are kept (resume after an interruption)."""
    label = T.TASKS[task]["label"]
    ths = cost_cfg["net_benefit_thresholds"]
    dmeta, emeta = dev.meta, ext.meta
    rows = np.flatnonzero(dmeta[label].notna().to_numpy())
    erows = np.flatnonzero(emeta[label].notna().to_numpy())
    y = np.full(len(dmeta), -1)
    y[rows] = dmeta[label].to_numpy()[rows].astype(int)
    ye = emeta[label].to_numpy()[erows].astype(int)
    groups = dmeta["group"].to_numpy()
    eg = emeta["group"].to_numpy()[erows]
    din, ein = S.Inputs(dev, bench["feature_set"]), S.Inputs(ext, bench["feature_set"])
    out = []

    def report(name, proba, params=None):
        pa = M.alert_probability(proba)
        ev = (ye >= M.ALERT_LEVEL).astype(int)
        if recorder is not None:
            recorder.save_predictions(f"external/{name}.npz", sample=erows, patient=emeta.patient.to_numpy()[erows],
                                      group=eg, y=ye, proba=proba, alert_updated=M.update_intercept(pa, ev))
        res = {"task": task, "lead_h": float(emeta.lead_h.iloc[0]), "candidate": name, "params": params,
               "n": len(ye), "patients": len(np.unique(eg)), **M.evaluate(proba, ye, ths)}
        for key, fn in (("rps", lambda i: M.rps(proba[i], ye[i])),
                        ("auroc_alert", lambda i: M.auroc(pa[i], ev[i])),
                        ("net_benefit_0.2", lambda i: M.net_benefit(pa[i], ev[i], 0.2))):
            _, lo, hi = V.cluster_bootstrap(fn, eg, n_boot=1000, seed=seed)
            res[f"{key}_lo"], res[f"{key}_hi"] = lo, hi
        upd = M.update_intercept(pa, ev)
        a, b = M.calibration_intercept_slope(upd, ev)
        res.update(updated_brier=M.brier(upd, ev), updated_cal_intercept=a, updated_cal_slope=b,
                   **{f"updated_net_benefit_{t:g}": M.net_benefit(upd, ev, t) for t in ths})
        out.append(res)
        if recorder is not None:
            recorder.add_external_row(res)

    done = set()
    prev = recorder.table("external/external.csv") if recorder is not None else None
    if prev is not None:
        out.extend(prev.to_dict("records"))
        done = set(prev.candidate)
    Xp, Xpe = din.persistence(), ein.persistence()
    for name, model in (("prior", T.Prior()), ("persistence", T.Persistence(table, task))):
        if name in done:
            continue
        model.fit(Xp.iloc[rows], y[rows])
        report(name, model.predict_proba(Xpe.iloc[erows]))
    for name in progress(candidates, desc=f"{task} final fit + Douala", unit="model"):
        if name in done:
            continue
        p, _, _, trials = S.search_candidate(name, din, table, task, y, groups, rows, bench, cost_cfg, seed)
        L = float(p["window"])
        model = S.build(name, p, table, task, seed)
        Xd = din.sequence(L) if name in S.SEQUENCE else din.tabular(L)
        Xe = ein.sequence(L) if name in S.SEQUENCE else ein.tabular(L)
        model.fit(S._take(Xd, rows), y[rows], groups[rows], din.values().iloc[rows])
        if recorder is not None:
            recorder.add_trials(trials.assign(repeat=-1, fold=-1).to_dict("records"))   # final search on all eICU
            recorder.save_model(name, model, p)
        report(name, model.predict_proba(S._take(Xe, erows)), json.dumps(p))
        S._log(f"{task} external validation: {name} done")
    return pd.DataFrame(out)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--tasks", nargs="+", default=["haemodynamic", "glycaemic"])
    ap.add_argument("--leads", nargs="+", type=float, default=[0.0])
    ap.add_argument("--candidates", nargs="+", default=ALL)
    ap.add_argument("--quick", action="store_true", help="small budgets, to check the pipeline")
    a = ap.parse_args(argv)
    bench, cost_cfg, table = S.load_bench(), O.load_cost(), load_thresholds()
    if a.quick:
        bench = copy.deepcopy(bench)
        bench["validation"].update(outer_folds=3, inner_folds=2, repeats=1)
        bench["search"]["trials"] = {k: 2 for k in bench["search"]["trials"]}
    OUT.mkdir(exist_ok=True)
    dev_df, ext_df = development_data(), douala_data()
    data_files = {"douala": DOUALA, "eicu_checksums": DEMO / "SHA256SUMS.txt"}
    for lead in a.leads:
        dev = make_samples(dev_df, table, eps=lead)
        ext = make_samples(ext_df, table, eps=lead)
        sites = dev_df.set_index("patient")["hospitalid"].groupby(level=0).first().reindex(dev.meta.patient).to_numpy()
        for task in a.tasks:
            run = Run(task, lead, a.candidates, bench, cost_cfg, THRESHOLDS, data_files, quick=a.quick)
            S.LOG_FILE = run.log_path
            S._log(f"run folder: {run.dir}")
            res = S.run(dev, sites, table, task, a.candidates, bench, cost_cfg, recorder=run)
            comps = [S.compare(res, c, "persistence") for c in a.candidates + ["selected"]]
            run.progress(stage="external validation")
            ext_res = external(dev, ext, table, task, a.candidates, bench, cost_cfg, recorder=run)
            summary = {
                "development": res.groupby("candidate")[["rps", "auroc_alert", "brier_alert", "cal_slope",
                                                         "net_benefit_0.2"]].mean().round(4).to_dict("index"),
                "vs_persistence": comps,
                "external": ext_res.set_index("candidate")[["rps", "rps_lo", "rps_hi", "auroc_alert",
                                                            "net_benefit_0.2"]].round(4).to_dict("index"),
            }
            run.finish(summary)
            S._log(f"run complete: {run.dir}")


if __name__ == "__main__":
    main()
