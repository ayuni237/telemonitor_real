"""Secondary results of a recorded benchmark run — thesis ch.4 §Benchmark.

From the saved outputs only (no new search, no refit), for each task:
  subgroups_<task>.tex    outer folds: RPS and AUROC of persistence and of the deployed
                          family by sex, age band (< 65, >= 65) and hospital; each repeat
                          pools its five outer folds, the table gives the mean of the repeats
  weights.tex             both tasks, final search on all eICU: share of 1000 random weightings of the
                          selection cost (Dirichlet, configs/cost.yaml) under which each
                          family has the lowest cost
  importance_<task>.tex   only if the deployed family beats persistence (corrected t test,
                          p < 0.05): grouped permutation importance on the Douala samples
                          and, for CatBoost, mean absolute tree SHAP values on eICU
  details.json            the same numbers, for the text
and, for the pgfplots figures (aggregates only, in ../memoire/figures/data):
  delta_rps_<task>.csv    RPS minus that of persistence, per outer fold and candidate
  transfer_<task>.csv     development RPS against Douala RPS with its interval
  decision_<task>.csv     net benefit on Douala: persistence, deployed family, treat all
  state_<data>_<outcome>.csv  AUROC of the state-evolution measures (12_state_comparison.py)

The deployed family is the one chosen by 11_export_model.py (artifacts/<task>/manifest.json).

Usage
  python scripts/15_results_details.py                       # latest complete run of each task
  python scripts/15_results_details.py --out <dir>           # default ../memoire/results
"""
import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

import _common
from telemonitor import explain as E, metrics as M, objective as O, run as R, search as S, validation as V
from telemonitor.labels import load_thresholds
from telemonitor.models import tabular as T
from telemonitor.windows import make_samples

NAMES = {"persistence": "Persistence", "catboost": "CatBoost", "forest": "Random forest", "grud": "GRU-D",
         "lstm": "Masked LSTM", "ordinal_logistic": "Ordinal logistic", "pca_logistic": "Logistic on PCA",
         "value_ridge": "Value forecast (ridge)", "value_catboost": "Value forecast (CatBoost)"}
GROUP_NAMES = {"pressure": "Pressure (systolic, diastolic, pulse pressure)", "pulse": "Pulse",
               "glucose": "Glucose", "static": "Age and sex"}


def latest_complete(task: str) -> Path | None:
    runs = [p for p in (_common.OUT / "runs").glob(f"{task}_0h_*")
            if (p / "manifest.json").exists()
            and json.loads((p / "manifest.json").read_text(encoding="utf8")).get("status") == "complete"]
    return max(runs, key=lambda p: p.stat().st_mtime) if runs else None


def fmt(x, nd=3):
    return "--" if pd.isna(x) else f"{x:.{nd}f}".replace("-", "$-$")


def outer_predictions(run: Path, name: str) -> pd.DataFrame:
    parts = []
    for f in sorted((run / "predictions" / "outer").glob(f"r*_f*/{name}.npz")):
        d = np.load(f, allow_pickle=True)
        rep = int(f.parent.name.split("_")[0][1:])
        parts.append(pd.DataFrame({"repeat": rep, "patient": d["patient"], "y": d["y"],
                                   **{f"p{k}": d["proba"][:, k] for k in range(d["proba"].shape[1])}}))
    return pd.concat(parts, ignore_index=True)


def scores(df: pd.DataFrame) -> tuple[float, float]:
    proba = df.filter(regex=r"^p\d$").to_numpy()
    y = df["y"].to_numpy()
    ev = (y >= M.ALERT_LEVEL).astype(int)
    auc = M.auroc(M.alert_probability(proba), ev) if 0 < ev.sum() < len(ev) else np.nan
    return M.rps(proba, y), auc


def subgroups(run: Path, family: str, patients: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for name in ("persistence", family):
        pr = outer_predictions(run, name).join(patients, on="patient")
        pr["age_band"] = np.where(pr["age"] >= 65, "65 and over", "under 65")
        cuts = [("All", pr)] + [(f"Sex {s}", pr[pr.sex == s]) for s in ("F", "M")] + \
               [(f"Age {a}", pr[pr.age_band == a]) for a in ("under 65", "65 and over")]
        for label, sub in cuts:
            per_rep = [scores(g) for _, g in sub.groupby("repeat")]
            rows.append({"subgroup": label, "model": name, "n": len(sub) // sub["repeat"].nunique(),
                         "rps": np.mean([r for r, _ in per_rep]), "auroc": np.nanmean([a for _, a in per_rep])})
        # hospitals: mean over repeats of the RPS in each hospital with at least 30 targets
        hosp = pr.groupby(["hospitalid", "repeat"]).apply(lambda g: scores(g)[0], include_groups=False)
        size = pr.groupby("hospitalid").size() / pr["repeat"].nunique()
        h = hosp.groupby(level=0).mean()[size >= 30]
        rows.append({"subgroup": "hospitals", "model": name, "per_hospital": h.to_dict()})
    return pd.DataFrame(rows)


def subgroup_table(task: str, family: str, sg: pd.DataFrame) -> str:
    plain = sg[sg.subgroup != "hospitals"]
    lines = []
    for label in plain.subgroup.unique():
        a = plain[(plain.subgroup == label) & (plain.model == "persistence")].iloc[0]
        b = plain[(plain.subgroup == label) & (plain.model == family)].iloc[0]
        lines.append(f"{label} & {int(a.n)} & {fmt(a.rps, 4)} & {fmt(b.rps, 4)} & "
                     f"{fmt(b.rps - a.rps, 4)} & {fmt(a.auroc)} & {fmt(b.auroc)} \\\\")
    hp = pd.Series(sg[(sg.subgroup == "hospitals") & (sg.model == "persistence")].iloc[0].per_hospital)
    hf = pd.Series(sg[(sg.subgroup == "hospitals") & (sg.model == family)].iloc[0].per_hospital)
    better = int((hf < hp).sum())
    return (
        "\\begin{table}[htbp]\n\\centering\\footnotesize\n"
        f"\\caption{{Outer-fold results by subgroup, {task} task: persistence against the deployed family "
        f"({NAMES[family]}). Each repeat pools its five outer folds; mean of the three repeats; $n$: targets "
        f"per repeat. In {better} of the {len(hp)} hospitals with at least 30 targets, {NAMES[family]} has a "
        f"lower RPS than persistence.}}\\label{{tab:subgroups-{task}}}\n"
        "\\begin{tabular}{@{}lrccccc@{}}\n\\toprule\n"
        " & & \\multicolumn{3}{c}{\\textbf{RPS}} & \\multicolumn{2}{c}{\\textbf{AUROC}} \\\\\n"
        "\\cmidrule(lr){3-5}\\cmidrule(l){6-7}\n"
        f"\\textbf{{Subgroup}} & \\textbf{{$n$}} & \\textbf{{Persist.}} & \\textbf{{{NAMES[family]}}} & "
        f"\\textbf{{$\\Delta$}} & \\textbf{{Persist.}} & \\textbf{{{NAMES[family]}}} \\\\\n\\midrule\n"
        + "\n".join(lines) + "\n\\bottomrule\n\\end{tabular}\n\\end{table}\n"), better, len(hp)


def weight_shares(run: Path, cfg: dict) -> pd.Series:
    tr = pd.read_csv(run / "trials.csv")
    kept = tr[(tr.repeat == -1) & (tr.kept.astype(bool))].drop_duplicates("candidate").set_index("candidate")
    share = O.rank_stability(kept, cfg, seed=0)
    return share.sort_values(ascending=False)


def weight_table(by_task: dict) -> str:
    """Both tasks side by side; families in the order of the equal-weight cost of the first task."""
    tasks = list(by_task)
    order = by_task[tasks[0]][1].sort_values().index
    lines = [NAMES[c] + "".join(f" & {fmt(by_task[t][1][c], 2)} & {100 * by_task[t][0][c]:.0f}\\%" for t in tasks)
             + " \\\\" for c in order]
    head = " & ".join(f"\\multicolumn{{2}}{{c}}{{\\textbf{{{t.capitalize()}}}}}" for t in tasks)
    rules = "".join(f"\\cmidrule(lr){{{2 + 2 * i}-{3 + 2 * i}}}" for i in range(len(tasks)))
    return ("\\begin{table}[htbp]\n\\centering\\footnotesize\n"
            "\\caption{Stability of the choice of family, final search on all eICU: selection cost with equal "
            "weights (lower is better), and share of 1\\,000 random weightings (uniform Dirichlet) under which "
            "the family has the lowest cost.}\\label{tab:weights}\n"
            "\\begin{tabular}{@{}l" + "cc" * len(tasks) + "@{}}\n\\toprule\n & " + head + " \\\\\n" + rules + "\n"
            "\\textbf{Family}" + " & \\textbf{Cost} & \\textbf{First}" * len(tasks) + " \\\\\n\\midrule\n"
            + "\n".join(lines) + "\n\\bottomrule\n\\end{tabular}\n\\end{table}\n")


def importance(task: str, family: str, run: Path, dev_df, ext_df, table, feature_set: str):
    params = json.loads((run / "external" / "models" / f"{family}.params.json").read_text(encoding="utf8"))
    model = joblib.load(run / "external" / "models" / f"{family}.joblib")
    L = float(params["window"])
    label = T.TASKS[task]["label"]
    out = {}
    for which, df in (("douala", ext_df), ("eicu", dev_df)):
        smp = make_samples(df, table, eps=0.0)
        rows = np.flatnonzero(smp.meta[label].notna().to_numpy())
        inp = S.Inputs(smp, feature_set)
        X = S._take(inp.sequence(L) if family in S.SEQUENCE else inp.tabular(L), rows)
        y = smp.meta[label].to_numpy()[rows].astype(int)
        out[which] = E.grouped_permutation_importance(model, X, y, n_repeats=20, seed=0)
        if family == "catboost" and which == "eicu":
            out["shap"] = E.catboost_shap(model, X).head(8)
    return out


def importance_table(task: str, family: str, imp: dict) -> str:
    d, e = imp["douala"].set_index("group"), imp["eicu"].set_index("group")
    lines = [f"{GROUP_NAMES[g]} & {fmt(e.loc[g, 'importance'], 4)} ({fmt(e.loc[g, 'sd'], 4)}) & "
             f"{fmt(d.loc[g, 'importance'], 4)} ({fmt(d.loc[g, 'sd'], 4)}) \\\\" for g in e.index]
    tex = ("\\begin{table}[htbp]\n\\centering\\footnotesize\n"
           f"\\caption{{Grouped permutation importance of the deployed model, {task} task ({NAMES[family]}): "
           "increase in RPS when the features of one group are permuted together, mean (SD) of 20 "
           f"permutations.}}\\label{{tab:importance-{task}}}\n"
           "\\begin{tabular}{@{}lcc@{}}\n\\toprule\n\\textbf{Group} & \\textbf{eICU} & \\textbf{Douala} \\\\\n"
           "\\midrule\n" + "\n".join(lines) + "\n\\bottomrule\n\\end{tabular}\n\\end{table}\n")
    return tex


ORDER = ["ordinal_logistic", "pca_logistic", "forest", "catboost", "value_ridge", "value_catboost", "grud", "lstm"]


def figure_data(task: str, family: str, run: Path, folds: pd.DataFrame, fig: Path):
    ref = folds[folds.candidate == "persistence"].set_index(["repeat", "fold"])["rps"]
    rows = []
    for i, c in enumerate(ORDER):
        cur = folds[folds.candidate == c].set_index(["repeat", "fold"])["rps"]
        for (r, f), v in (cur - ref.loc[cur.index]).items():
            rows.append({"x": i + 1, "candidate": c, "repeat": r, "fold": f, "delta": v})
    rows = pd.DataFrame(rows)
    rows.to_csv(fig / f"delta_rps_{task}.csv", index=False)
    rows.groupby(["x", "candidate"], as_index=False)["delta"].mean().to_csv(fig / f"delta_rps_mean_{task}.csv", index=False)
    ext = pd.read_csv(run / "external" / "external.csv").set_index("candidate")
    dev = folds.groupby("candidate")["rps"].mean()
    keep = ["persistence"] + ORDER
    pd.DataFrame({"x": range(len(keep)), "candidate": keep, "development": dev.reindex(keep).to_numpy(),
                  "douala": ext.loc[keep, "rps"].to_numpy(), "lo": ext.loc[keep, "rps_lo"].to_numpy(),
                  "hi": ext.loc[keep, "rps_hi"].to_numpy()}).assign(
        plus=lambda t: t.hi - t.douala, minus=lambda t: t.douala - t.lo).to_csv(fig / f"transfer_{task}.csv", index=False)
    dc = pd.read_csv(run / "figures" / "external_decision_curves.csv")
    wide = dc[dc.model.isin(["persistence", family])].pivot(index="threshold", columns="model", values="net_benefit")
    wide["treat_all"] = dc.groupby("threshold")["treat_all"].first()
    wide.rename(columns={family: "deployed"}).reset_index().to_csv(fig / f"decision_{task}.csv", index=False)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=_common.ROOT.parent / "memoire" / "results")
    ap.add_argument("--figures", type=Path, default=_common.ROOT.parent / "memoire" / "figures" / "data")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    sc = pd.read_csv(_common.OUT / "state_comparison.csv")
    sc["x"] = sc.groupby(["data", "outcome"]).cumcount() + 1
    sc["plus"], sc["minus"] = sc.hi - sc.auroc, sc.auroc - sc.lo
    for (data, outcome), g in sc.groupby(["data", "outcome"]):
        g.to_csv(a.figures / f"state_{data}_{outcome}.csv", index=False)
    cfg, table, bench = O.load_cost(), load_thresholds(), S.load_bench()
    dev_df, ext_df = R.development_data(), R.douala_data()
    patients = dev_df.groupby("patient")[["age", "sex", "hospitalid"]].first()
    details, weights = {}, {}
    for task in ("haemodynamic", "glycaemic"):
        run = latest_complete(task)
        if run is None:
            print(f"{task}: no complete run; skipped")
            continue
        family = json.loads((_common.ROOT / "artifacts" / task / "manifest.json").read_text(encoding="utf8"))["candidate"]
        sg = subgroups(run, family, patients)
        tex, better, nh = subgroup_table(task, family, sg)
        (a.out / f"subgroups_{task}.tex").write_text(tex, encoding="utf8")
        share = weight_shares(run, cfg)
        tr = pd.read_csv(run / "trials.csv")
        cost = tr[(tr.repeat == -1) & (tr.kept.astype(bool))].drop_duplicates("candidate").set_index("candidate")
        cost = O.selection_cost(cost, cfg)
        weights[task] = (share, cost)
        details[task] = {"run": run.name, "family": family,
                         "subgroups": sg[sg.subgroup != "hospitals"].drop(columns="per_hospital", errors="ignore").to_dict("records"),
                         "hospitals_better": better, "hospitals": nh, "weight_share_first": share.to_dict()}
        # interpretability only for a model shown to beat persistence
        folds = pd.read_csv(run / "folds.csv")
        ref = folds[folds.candidate == "persistence"].set_index(["repeat", "fold"])
        cur = folds[folds.candidate == family].set_index(["repeat", "fold"])
        d = (cur["rps"] - ref.loc[cur.index, "rps"]).to_numpy()
        _, p = V.corrected_ttest(d, cur["n_train"].mean(), cur["n_test"].mean())
        details[task]["p_vs_persistence"] = p
        figure_data(task, family, run, folds, a.figures)
        if p < 0.05 and d.mean() < 0:
            imp = importance(task, family, run, dev_df, ext_df, table, bench["feature_set"])
            (a.out / f"importance_{task}.tex").write_text(importance_table(task, family, imp), encoding="utf8")
            details[task]["importance"] = {k: v.to_dict("records") for k, v in imp.items()}
        print(f"{run.name}: details written to {a.out}")
    if weights:
        (a.out / "weights.tex").write_text(weight_table(weights), encoding="utf8")
    (a.out / "details.json").write_text(json.dumps(details, indent=1, default=float), encoding="utf8")
