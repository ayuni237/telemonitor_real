"""LaTeX tables of a recorded benchmark run — thesis ch.4 §Benchmark, §External validation.

From the saved results only (no refit), for each task:
  benchmark_<task>.tex   outer folds: mean (SD) per candidate of RPS, Brier, AUROC,
                         calibration intercept and slope, mean net benefit over the
                         thresholds; difference in RPS with persistence and the
                         corrected resampled t test (Nadeau and Bengio 2003)
  selected_<task>.tex    family chosen by the procedure in each outer fold
  external_<task>.tex    Douala: RPS and AUROC with patient-bootstrap intervals,
                         calibration before and after the intercept update
  leads.tex              hypothesis H2, once a task has runs at several leads: difference
                         in RPS with persistence and its test, for the next reading and for
                         targets 24 and 48 h ahead (embargoes of 12 and 36 h)
  summary.json           the same numbers, for the text

The tables above leads.tex use the runs at lead 0 only. A run that is not complete is
refused, so that partial numbers do not reach the thesis; --partial writes them anyway,
with the number of folds in each caption.

Usage
  python scripts/13_results_tables.py                      # latest run of each task and lead
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
LEAD_NAMES = {0.0: "Next reading", 12.0: "24 h ahead", 36.0: "48 h ahead"}


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
        p = p_cell(r.get("p"))
        d = "--" if c == "persistence" else fmt(r["d_rps"], 4, sign=True)
        rows.append(f"{NAMES[c]} & {fmt(r.rps_mean, 4)} ({fmt(r.rps_sd, 4)}) & {d} & {p} & "
                    f"{fmt(r.brier_alert_mean)} & {fmt(r.auroc_alert_mean)} ({fmt(r.auroc_alert_sd, 2)}) & "
                    f"{fmt(r.cal_intercept_mean, 2)} & {fmt(r.cal_slope_mean, 2)} & {fmt(r.net_benefit_mean)} \\\\")
        if c == "persistence":
            rows.append(r"\addlinespace")
    folds = int(s["folds"].max())
    return "\n".join([
        r"\begin{table}[htbp]", r"\centering\footnotesize\setlength{\tabcolsep}{4pt}",
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


def p_cell(p) -> str:
    return "--" if pd.isna(p) else ("$<0.001$" if p < 0.001 else f"{p:.3f}")


def samples_per_repeat(folds: pd.DataFrame) -> int:
    """Development samples: the outer test folds of one repeat cover them once."""
    per = folds[folds.candidate == "persistence"].groupby("repeat")["n_test"].sum()
    return int(round(per.mean()))


def leads_table(leads: dict) -> tuple[str, dict]:
    """Hypothesis H2: RPS difference with persistence and its test, per task and lead."""
    cols = sorted({lead for by_lead in leads.values() for lead in by_lead})
    width = 1 + 2 * len(cols)
    head = " & ".join(rf"\multicolumn{{2}}{{c}}{{\textbf{{{LEAD_NAMES.get(lead, f'{lead:g} h embargo')}}}}}"
                      for lead in cols)
    rule = "".join(rf"\cmidrule(lr){{{2 + 2 * i}-{3 + 2 * i}}}" for i in range(len(cols)))
    rows, out = [], {}
    for task, by_lead in leads.items():
        rows += [r"\midrule", rf"\multicolumn{{{width}}}{{@{{}}l}}{{\textit{{{task.capitalize()} task}}}} \\"]
        span = lambda f: " & ".join(rf"\multicolumn{{2}}{{c}}{{{f(by_lead[l]) if l in by_lead else '--'}}}" for l in cols)
        rows.append("Samples & " + span(lambda v: f"{v[1]:,}".replace(",", r"\,")) + r" \\")
        rows.append("Persistence (RPS) & " + span(lambda v: fmt(v[0].loc["persistence", "rps_mean"], 4)) + r" \\")
        for c in ORDER:
            if c in ("prior", "persistence") or not any(c in v[0].index for v in by_lead.values()):
                continue
            cells = []
            for lead in cols:
                s = by_lead[lead][0] if lead in by_lead else None
                ok = s is not None and c in s.index
                cells += [fmt(s.loc[c, "d_rps"], 4, sign=True) if ok else "--", p_cell(s.loc[c].get("p")) if ok else "--"]
            rows.append(f"{NAMES[c]} & " + " & ".join(cells) + r" \\")
        out[task] = {f"{lead:g}": {"samples": v[1], "outer": v[0].reset_index()[["candidate", "rps_mean", "d_rps", "p"]]
                                   .to_dict("records")} for lead, v in by_lead.items()}
    tex = "\n".join([
        r"\begin{table}[htbp]", r"\centering\footnotesize\setlength{\tabcolsep}{4pt}",
        r"\caption{Lead time (hypothesis H2): difference in RPS with persistence (negative is better) and corrected "
        r"resampled $t$ test, mean over the outer folds, for the next reading and for targets 24 and 48~hours ahead "
        r"(embargoes of 12 and 36~hours). Samples: development samples of one repeat.}\label{tab:leads}",
        rf"\begin{{tabular}}{{@{{}}l{'cc' * len(cols)}@{{}}}}", r"\toprule",
        rf" & {head} \\", rule, r"\textbf{Model} & " + " & ".join([r"$\Delta$RPS & $p$"] * len(cols)) + r" \\",
        *rows, r"\bottomrule", r"\end{tabular}", r"\end{table}", ""])
    return tex, out


def run_key(run: Path) -> tuple[str, float]:
    inputs = json.loads((run / "manifest.json").read_text())["inputs"]
    return inputs["task"], float(inputs.get("lead_h", 0.0))


def latest_runs(runs_dir: Path) -> dict[tuple[str, float], Path]:
    """Latest recorded run of each task and lead."""
    found = sorted((p for p in runs_dir.glob("*") if (p / "folds.csv").exists()), key=lambda p: p.stat().st_mtime)
    return {run_key(p): p for p in found}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", type=Path, action="append")
    ap.add_argument("--out", type=Path, default=_common.ROOT.parent / "memoire" / "results")
    ap.add_argument("--partial", action="store_true", help="accept runs that are not complete")
    a = ap.parse_args()
    runs = {run_key(r): r for r in a.run} if a.run else latest_runs(_common.OUT / "runs")
    if not runs:
        raise SystemExit("no recorded run in out/runs")
    a.out.mkdir(parents=True, exist_ok=True)
    # one run per call is allowed: keep the other tasks already written
    sfile = a.out / "summary.json"
    summary = json.loads(sfile.read_text(encoding="utf8")) if sfile.exists() else {}
    leads = {}
    for (task, lead), run in sorted(runs.items()):
        man = json.loads((run / "manifest.json").read_text())
        prog = man.get("progress", {})
        done, total = prog.get("folds_done"), prog.get("folds_total")
        complete = man.get("status") == "complete"
        if not complete and not a.partial:
            print(f"{run.name}: not complete ({done} of {total} outer folds); skipped (use --partial)")
            continue
        extra = "" if complete else f" (partial run: {done} of {total} folds)"
        folds = pd.read_csv(run / "folds.csv")
        s = outer_summary(folds)
        leads.setdefault(task, {})[lead] = (s, samples_per_repeat(folds))
        if lead != 0:
            print(f"{run.name}: lead {lead:g} h, used in leads.tex only")
            continue
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
    if any(len(by_lead) > 1 for by_lead in leads.values()):
        tex, summary["leads"] = leads_table({t: v for t, v in leads.items() if len(v) > 1})
        (a.out / "leads.tex").write_text(tex, encoding="utf8")
        print(f"leads.tex written to {a.out}")
    if summary:
        sfile.write_text(json.dumps(summary, indent=1, default=float), encoding="utf8")
