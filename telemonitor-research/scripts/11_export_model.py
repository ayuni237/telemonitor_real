"""Step 11 — export the model chosen by the benchmark to the risk service.

Thesis ch.3 §Training protocol: the selection procedure is nested; applied once
more to all development data, it chooses the deployed model. In a complete run,
the final search on all eICU (trials.csv, repeat = -1) gives each family's kept
configuration with its inner measures; the family with the lowest selection
cost (configs/cost.yaml) is deployed, with the model fitted on all eICU in the
external-validation step (external/models/<family>.joblib).

    python scripts/11_export_model.py                       latest complete run of each task
    python scripts/11_export_model.py --run out/runs/<dir>  one run

Writes artifacts/<task>/ (model.joblib + manifest.json), read by the risk
service and the worker; restart them afterwards.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import pandas as pd
import yaml

import _common
from telemonitor import objective as O
from telemonitor.labels import load_thresholds
from telemonitor.serve import artifact

ARTIFACTS = _common.ROOT / "artifacts"


def latest_complete(task: str, lead: int = 0) -> Path | None:
    runs = []
    for p in (_common.OUT / "runs").glob(f"{task}_{lead}h_*"):
        m = p / "manifest.json"
        if m.exists() and json.loads(m.read_text(encoding="utf8")).get("status") == "complete":
            runs.append(p)
    return max(runs, key=lambda p: p.stat().st_mtime) if runs else None


def choose(run: Path) -> tuple[str, pd.Series]:
    """Family with the lowest selection cost in the final search, and its inner measures."""
    trials = pd.read_csv(run / "trials.csv")
    final = trials[(trials["repeat"] == -1) & trials["kept"].astype(bool)].set_index("candidate")
    if final.empty:
        raise SystemExit(f"{run.name}: no final search in trials.csv (run not complete?)")
    cost_cfg = yaml.safe_load((run / "config" / "cost.yaml").read_text(encoding="utf8"))
    cost = O.selection_cost(final, cost_cfg)
    print(f"{run.name}: selection cost of the final search\n{cost.sort_values().round(3).to_string()}")
    best = str(cost.idxmin())
    return best, final.loc[best]


def export(run: Path) -> Path:
    manifest = json.loads((run / "manifest.json").read_text(encoding="utf8"))
    task = manifest["inputs"]["task"]
    bench = manifest["inputs"]["benchmark"]
    run_version = yaml.safe_load((run / "config" / "thresholds.yaml").read_text(encoding="utf8"))["version"]
    table = load_thresholds()
    if run_version != table.version:
        raise SystemExit(f"{run.name} was labelled with thresholds {run_version}, the service uses {table.version}: "
                         "rerun the benchmark")
    name, inner = choose(run)
    models = run / "external" / "models"
    model = joblib.load(models / f"{name}.joblib")
    params = json.loads((models / f"{name}.params.json").read_text(encoding="utf8"))
    ext = pd.read_csv(run / "external" / "external.csv").set_index("candidate")
    metrics = {"inner": {k: float(inner[k]) for k in ("rps", "auroc_alert", "brier_alert") if k in inner},
               "douala": {k: float(ext.loc[name, k]) for k in ("rps", "rps_lo", "rps_hi", "auroc_alert")
                          if name in ext.index and k in ext.columns}}
    out = ARTIFACTS / task
    a = artifact.save(model, out, task=task, candidate=name, window=float(params["window"]),
                      feature_set=bench["feature_set"], threshold_version=table.version, params=params,
                      development=run.name, metrics=metrics)
    print(f"{task}: {a.version} -> {out}")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", type=Path, help="run folder (default: latest complete run of each task)")
    ap.add_argument("--tasks", nargs="+", default=["haemodynamic", "glycaemic"])
    a = ap.parse_args(argv)
    runs = [a.run] if a.run else [r for t in a.tasks if (r := latest_complete(t))]
    if not runs:
        raise SystemExit("no complete run in out/runs: finish the benchmark first (06_benchmark.py)")
    for run in runs:
        export(run)


if __name__ == "__main__":
    main()
