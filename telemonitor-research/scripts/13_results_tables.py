"""LaTeX tables of a recorded benchmark run — thesis ch.4 §Benchmark, §External validation.

From the saved results only (no refit), for each task:
  benchmark_<task>.tex   outer folds: mean (SD) per candidate of RPS, Brier, AUROC,
                         calibration intercept and slope, mean net benefit over the
                         thresholds; difference in RPS with persistence and the
                         corrected resampled t test (Nadeau and Bengio 2003)
  selected_<task>.tex    family chosen by the procedure in each outer fold
  external_<task>.tex    Douala: RPS and AUROC with patient-bootstrap intervals,
                         calibration before and after the intercept update
  summary.json           the same numbers, for the text

A run that is not complete is refused, so that partial numbers do not reach the
thesis; --partial writes them anyway, with the number of folds in each caption.

Usage
  python scripts/13_results_tables.py                      # latest run of each task
  python scripts/13_results_tables.py --run out/runs/glycaemic_0h_<id> [--partial]
  python scripts/13_results_tables.py --out <dir>          # default ../memoire/results
"""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

import _common
from telemonitor import validation as V

ORDER = ["prior", "persistence", "ordinal_logistic", "pca_logistic", "forest", "catboost",
         "value_ridge", "value_catboost", "grud", "lstm", "selected"]
NAMES = {"prior": "Prior", "persistence": "Persistence", "ordinal_logistic": "Ordinal logistic",
         "pca_logistic": "Logistic on PCA", "forest": "Random forest", "catboost": "CatBoost",
         "value_ridge": "Value forecast (ridge)", "value_catboost": "Value forecast (CatBoost)",
         "grud": "GRU-D", "lstm": "Masked LSTM", "selected": "Selected (procedure)"}
TASKS = {"haemodynamic": "haemodynamic", "glycaemic": "glycaemic"}


def nb_columns(df: pd.DataFrame) -> list[str]:
    return [c for c in df.columns if c.startswith("net_benefit_") and not c.startswith("net_benefit_all")]


def fmt(x, nd=3, sign=False):
    """Number for a table cell, with a typographic minus."""
    if pd.isna(x):
        return "--"
    return (f"{x:+.{nd}f}" if sign else f"{x:.{nd}f}").replace("-", "$-$")


def outer_summary(folds: pd.DataFrame) -> pd.DataFrame:
    """Mean and SD over outer folds per candidate; RPS difference with persistence and its test."""
    folds = folds.assign(net_benefit=folds[nb_columns(folds)].mean(axis=1))
    metrics = ["rps", "brier_alert", "auroc_alert", "cal_intercept", "cal_slope", "net_benefit"]
    g = folds.groupby("candidate")
    out = g[metrics].mean().add_suffix("_mean").join(g[metrics].std(ddof=1).add_suffix("_sd"))
    out["folds"] = g.size()
    ref = folds[folds.candidate == "persistence"].set_index(["repeat", "fold"])
    for c in out.index:
        cur = folds[folds.candidate == c].set_index(["repeat", "fold"])
        common = cur.index.intersection(ref.index)
        d = (cur.loc[common, "rps"] - ref.loc[common, "rps"]).to_numpy()
        out.loc[c, "d_rps"] = d.mean() if len(d) else np.nan
        if c != "persistence" and len(d) > 1:
            t, p = V.corrected_ttest(d, cur.loc[common, "n_train"].mean(), cur.loc[common, "n_test"].mean())
            out.loc[c, "t"], out.loc[c, "p"] = t, p
    return out.reindex([m for m in ORDER if m in out.index])


def benchmark_table(task: str, s: pd.DataFrame, caption_extra: str) -> str:
    rows = []
    for c, r in s.iterrows():
        p = "--" if pd.isna(r.get("p")) else ("$<0.001$" if r["p"] < 0.001 else f"{r['p']:.3f}")
        d = "--" if c == "persistence" else fmt(r["d_rps"], 4, sign=True)
        rows.append(f"{NAMES[c]} & {fmt(r.rps_mean, 4)} ({fmt(r.rps_sd, 4)}) & {d} & {p} & "
                    f"{fmt(r.brier_alert_mean)} & {fmt(r.auroc_alert_mean)} ({fmt(r.auroc_alert_sd, 2)}) & "
                    f"{fmt(r.cal_intercept_mean, 2)} & {fmt(r.cal_slope_mean, 2)} & {fmt(r.net_benefit_mean)} \\\\")
        if c == "persistence":
            rows.append(r"\addlinespace")
    folds = int(s["folds"].max())
    return "\n".join([
        r"\begin{table}[htbp]", r"\centering\footnotesize",
        rf"\caption{{Outer-fold results, {task} task: mean (SD) over {folds} outer folds{caption_extra}. "
        r"$\Delta$RPS: difference with persistence (negative is better); $p$: corrected resampled $t$ test. "
        r"Net benefit averaged over the thresholds 0.1 to 0.3.}" + rf"\label{{tab:bench-{task}}}",
        r"\begin{tabular}{@{}lcccccccc@{}}", r"\toprule",
        r"\textbf{Model} & \textbf{RPS} & \textbf{$\Delta$RPS} & \textbf{$p$} & \textbf{Brier} & "
        r"\textbf{AUROC} & \textbf{Int.} & \textbf{Slope} & \textbf{NB} \\", r"\midrule",
        *rows, r"\bottomrule", r"\end{tabular}", r"\end{table}", ""])


def selected_table(task: str, folds: pd.DataFrame) -> tuple[str, dict]:
    sel = folds[folds.candidate == "selected"]
    fam = sel["params"].map(lambda s: json.loads(s)["family"] if isinstance(s, str) else None)
    counts = fam.value_counts().to_dict()
    body = ", ".join(f"{NAMES.get(k, k)} {v}" for k, v in counts.items())
    return (f"% {task}: family selected in the {len(sel)} outer folds: {body}\n", counts)


def external_table(task: str, ext: pd.DataFrame) -> str:
    ext = ext.set_index("candidate").reindex([m for m in ORDER if m in set(ext.candidate)])
    rows = []
    for c, r in ext.iterrows():
        rows.append(f"{NAMES[c]} & {fmt(r.rps, 4)} [{fmt(r.rps_lo, 4)}, {fmt(r.rps_hi, 4)}] & "
                    f"{fmt(r.auroc_alert)} [{fmt(r.auroc_alert_lo, 2)}, {fmt(r.auroc_alert_hi, 2)}] & "
                    f"{fmt(r.cal_intercept, 2)} & {fmt(r.cal_slope, 2)} & "
                    f"{fmt(r.updated_cal_intercept, 2)} & {fmt(r.updated_cal_slope, 2)} \\\\")
    n, pts = int(ext["n"].iloc[0]), int(ext["patients"].iloc[0])
    return "\n".join([
        r"\begin{table}[htbp]", r"\centering\footnotesize",
        rf"\caption{{External validation on the Douala charts, {task} task ({n} targets, {pts} patients). "
        r"95\% intervals by patient bootstrap. Calibration intercept and slope as is, then after the intercept update.}"
        + rf"\label{{tab:ext-{task}}}",
        r"\begin{tabular}{@{}lcccccc@{}}", r"\toprule",
        r" & & & \multicolumn{2}{c}{\textbf{As is}} & \multicolumn{2}{c}{\textbf{Updated}} \\",
        r"\cmidrule(lr){4-5}\cmidrule(l){6-7}",
        r"\textbf{Model} & \textbf{RPS} & \textbf{AUROC} & \textbf{Int.} & \textbf{Slope} & \textbf{Int.} & \textbf{Slope} \\",
        r"\midrule", *rows, r"\bottomrule", r"\end{tabular}", r"\end{table}", ""])


def latest_runs(runs_dir: Path) -> list[Path]:
    found = sorted((p for p in runs_dir.glob("*") if (p / "folds.csv").exists()), key=lambda p: p.stat().st_mtime)
    by_task = {}
    for p in found:
        by_task[json.loads((p / "manifest.json").read_text())["inputs"]["task"]] = p
    return list(by_task.values())


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", type=Path, action="append")
    ap.add_argument("--out", type=Path, default=_common.ROOT.parent / "memoire" / "results")
    ap.add_argument("--partial", action="store_true", help="accept runs that are not complete")
    a = ap.parse_args()
    runs = a.run or latest_runs(_common.OUT / "runs")
    if not runs:
        raise SystemExit("no recorded run in out/runs")
    a.out.mkdir(parents=True, exist_ok=True)
    summary = {}
    for run in runs:
        man = json.loads((run / "manifest.json").read_text())
        task, prog = man["inputs"]["task"], man.get("progress", {})
        done, total = prog.get("folds_done"), prog.get("folds_total")
        complete = man.get("status") == "complete"
        if not complete and not a.partial:
            print(f"{run.name}: not complete ({done} of {total} outer folds); skipped (use --partial)")
            continue
        extra = "" if complete else f" (partial run: {done} of {total} folds)"
        folds = pd.read_csv(run / "folds.csv")
        s = outer_summary(folds)
        (a.out / f"benchmark_{task}.tex").write_text(benchmark_table(task, s, extra), encoding="utf8")
        sel_tex, counts = selected_table(task, folds)
        (a.out / f"selected_{task}.tex").write_text(sel_tex, encoding="utf8")
        summary[task] = {"run": run.name, "complete": complete, "folds_done": done, "folds_total": total,
                         "outer": s.reset_index().to_dict("records"), "selected_family": counts}
        ext_csv = run / "external" / "external.csv"
        if ext_csv.exists():
            ext = pd.read_csv(ext_csv)
            (a.out / f"external_{task}.tex").write_text(external_table(task, ext), encoding="utf8")
            summary[task]["external"] = ext.to_dict("records")
        print(f"{run.name}: tables written to {a.out}")
    if summary:
        (a.out / "summary.json").write_text(json.dumps(summary, indent=1, default=float), encoding="utf8")
