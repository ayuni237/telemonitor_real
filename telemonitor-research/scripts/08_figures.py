"""Redraw the figures of a recorded run — from its saved results only, no refit.

Usage
  python scripts/08_figures.py                    # latest run in out/runs
  python scripts/08_figures.py --run out/runs/haemodynamic_0h_<id>
  python scripts/08_figures.py --all              # every run

For each run, writes <run>/figures/: one PDF (for LaTeX) and one PNG per figure,
and the CSV of the plotted values next to it, so any figure can be redrawn
elsewhere (pgfplots, another tool) from the same numbers.
  1. outer_rps / outer_auroc   distribution over outer folds, per model
  2. roc                       ROC curve of the alert, pooled outer predictions (repeat 0)
  3. calibration               observed vs predicted alert risk, deciles, Wilson 95% intervals
  4. decision_curves           net benefit against decision threshold, with treat-all / treat-none
  5. external_rps              Douala RPS with patient-bootstrap intervals, beside development
  6. external_decision_curves  net benefit on Douala
Pooled curves use repeat 0 only, where each development sample is predicted once.
"""
import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.metrics import roc_auc_score, roc_curve  # noqa: E402

import _common  # noqa: E402
from telemonitor import metrics as M  # noqa: E402

# Reference palette (dataviz skill, light mode): slot 1 development, slot 2 Douala; greys for references.
BLUE, ORANGE = "#2a78d6", "#eb6834"
INK, INK2, GRID, REF = "#0b0b0b", "#52514e", "#e4e3df", "#8a8984"
plt.rcParams.update({
    "font.size": 8, "axes.titlesize": 8, "axes.labelsize": 8, "xtick.labelsize": 7, "ytick.labelsize": 7,
    "axes.edgecolor": INK2, "axes.labelcolor": INK, "xtick.color": INK2, "ytick.color": INK2,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6, "axes.axisbelow": True,
    "axes.spines.top": False, "axes.spines.right": False, "lines.linewidth": 1.6,
    "figure.dpi": 150, "savefig.bbox": "tight", "pdf.fonttype": 42,
})
ORDER = ["prior", "persistence", "ordinal_logistic", "pca_logistic", "forest", "catboost",
         "value_ridge", "value_catboost", "grud", "lstm", "selected"]
NAMES = {"prior": "Prior", "persistence": "Persistence", "ordinal_logistic": "Ordinal logistic",
         "pca_logistic": "Logistic on PCA", "forest": "Random forest", "catboost": "CatBoost",
         "value_ridge": "Value forecast (ridge)", "value_catboost": "Value forecast (CatBoost)",
         "grud": "GRU-D", "lstm": "Masked LSTM", "selected": "Selected (procedure)"}
THRESHOLDS = np.round(np.arange(0.02, 0.61, 0.01), 2)


def save(fig, out: Path, name: str, data: pd.DataFrame):
    fig.savefig(out / f"{name}.pdf")
    fig.savefig(out / f"{name}.png", dpi=200)
    data.to_csv(out / f"{name}.csv", index=False)
    plt.close(fig)


def pooled(run: Path, repeat: int = 0) -> dict:
    """Outer predictions of one repeat, concatenated over folds, per model."""
    out = {}
    for d in sorted((run / "predictions" / "outer").glob(f"r{repeat}_f*")):
        for f in d.glob("*.npz"):
            z = np.load(f)
            out.setdefault(f.stem, []).append((z["y"], z["proba"]))
    return {k: (np.concatenate([a for a, _ in v]), np.concatenate([b for _, b in v])) for k, v in out.items()}


def grid(n):
    cols = min(5, n)
    rows = int(np.ceil(n / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(1.9 * cols, 1.8 * rows), sharex=True, sharey=True, squeeze=False)
    for ax in axes.flat[n:]:
        ax.set_visible(False)
    return fig, axes.flat


def fold_distributions(folds: pd.DataFrame, out: Path, metric: str, label: str):
    models = [m for m in ORDER if m in set(folds.candidate)]
    means = folds.groupby("candidate")[metric].mean().reindex(models)
    # best model at the top: RPS is minimised, AUROC maximised (y increases upwards)
    models = means.sort_values(ascending=(metric == "rps")).index.tolist()[::-1]
    fig, ax = plt.subplots(figsize=(4.6, 0.32 * len(models) + 0.8))
    rng = np.random.default_rng(0)
    for i, m in enumerate(models):
        v = folds.loc[folds.candidate == m, metric].to_numpy()
        ax.scatter(v, i + rng.uniform(-0.12, 0.12, len(v)), s=12, color=BLUE, alpha=0.55, linewidths=0)
        ax.plot([v.mean()] * 2, [i - 0.3, i + 0.3], color=INK, lw=1.6)
    if "persistence" in models:
        ax.axvline(means["persistence"], color=REF, ls="--", lw=1, zorder=0)
    ax.set_yticks(range(len(models)), [NAMES[m] for m in models])
    ax.set_xlabel(f"{label} on the outer test hospitals (dots: folds; bar: mean; dashed: persistence)")
    ax.grid(axis="y", visible=False)
    save(fig, out, f"outer_{metric.split('_')[0]}", folds[["repeat", "fold", "candidate", metric]])


def roc_figure(pool: dict, out: Path):
    models = [m for m in ORDER if m in pool]
    fig, axes = grid(len(models))
    rows = []
    for ax, m in zip(axes, models):
        y, p = pool[m]
        e = (y >= M.ALERT_LEVEL).astype(int)
        pa = M.alert_probability(p)
        fpr, tpr, _ = roc_curve(e, pa)
        auc = roc_auc_score(e, pa)
        ax.plot([0, 1], [0, 1], color=REF, lw=1, ls="--")
        ax.plot(fpr, tpr, color=BLUE)
        ax.set_title(f"{NAMES[m]}\nAUC {auc:.3f}", color=INK)
        rows += [{"model": m, "fpr": a, "tpr": b} for a, b in zip(fpr, tpr)]
    fig.supxlabel("1 - specificity", fontsize=8)
    fig.supylabel("sensitivity", fontsize=8)
    save(fig, out, "roc", pd.DataFrame(rows))


def calibration_figure(pool: dict, out: Path, name="calibration", color=BLUE):
    models = [m for m in ORDER if m in pool]
    fig, axes = grid(len(models))
    rows = []
    for ax, m in zip(axes, models):
        y, p = pool[m]
        e = (y >= M.ALERT_LEVEL).astype(int)
        cc = M.calibration_curve(M.alert_probability(p), e, bins=10)
        ax.plot([0, 1], [0, 1], color=REF, lw=1, ls="--")
        err = np.clip([cc.observed - cc.low, cc.high - cc.observed], 0, None)   # rounding at 0 or 1
        ax.errorbar(cc.predicted, cc.observed, yerr=err,
                    fmt="o", ms=4, color=color, ecolor=color, elinewidth=1, capsize=0)
        a, b = M.calibration_intercept_slope(M.alert_probability(p), e)
        ax.set_title(f"{NAMES[m]}\nintercept {a:.2f}, slope {b:.2f}", color=INK)
        rows += cc.assign(model=m).to_dict("records")
    fig.supxlabel("predicted probability of an alert", fontsize=8)
    fig.supylabel("observed proportion", fontsize=8)
    save(fig, out, name, pd.DataFrame(rows))


def decision_figure(pool: dict, out: Path, name="decision_curves", color=BLUE):
    models = [m for m in ORDER if m in pool]
    fig, axes = grid(len(models))
    rows = []
    for ax, m in zip(axes, models):
        y, p = pool[m]
        e = (y >= M.ALERT_LEVEL).astype(int)
        pa = M.alert_probability(p)
        nb = [M.net_benefit(pa, e, t) for t in THRESHOLDS]
        nb_all = [M.net_benefit_treat_all(e, t) for t in THRESHOLDS]
        ax.axhline(0, color=REF, lw=1)
        ax.plot(THRESHOLDS, nb_all, color=REF, lw=1, ls="--")
        ax.plot(THRESHOLDS, nb, color=color)
        ax.set_ylim(-0.05, max(0.05, e.mean() * 1.1))
        ax.set_title(NAMES[m], color=INK)
        rows += [{"model": m, "threshold": t, "net_benefit": a, "treat_all": b} for t, a, b in zip(THRESHOLDS, nb, nb_all)]
    fig.supxlabel("decision threshold (dashed: alert everyone; flat: alert no one)", fontsize=8)
    fig.supylabel("net benefit", fontsize=8)
    save(fig, out, name, pd.DataFrame(rows))


def external_figures(run: Path, folds: pd.DataFrame, out: Path):
    ext = pd.read_csv(run / "external" / "external.csv")
    dev = folds.groupby("candidate").rps.mean()
    models = [m for m in ORDER if m in set(ext.candidate)]
    e = ext.set_index("candidate").reindex(models)
    fig, ax = plt.subplots(figsize=(4.6, 0.34 * len(models) + 0.9))
    yy = np.arange(len(models))
    ax.errorbar(e.rps, yy + 0.12, xerr=[e.rps - e.rps_lo, e.rps_hi - e.rps], fmt="o", ms=4, color=ORANGE,
                elinewidth=1, label="Douala (patient bootstrap 95% interval)")
    ax.scatter(dev.reindex(models), yy - 0.12, s=16, color=BLUE, label="eICU development (mean of outer folds)")
    ax.set_yticks(yy, [NAMES[m] for m in models])
    ax.set_xlabel("ranked probability score (lower is better)")
    ax.legend(loc="lower right", frameon=False, fontsize=7)
    ax.grid(axis="y", visible=False)
    save(fig, out, "external_rps", e.reset_index()[["candidate", "rps", "rps_lo", "rps_hi"]].assign(
        development_rps=dev.reindex(models).to_numpy()))
    pool = {}
    for f in (run / "external").glob("*.npz"):
        z = np.load(f)
        pool[f.stem] = (z["y"], z["proba"])
    if pool:
        decision_figure(pool, out, "external_decision_curves", ORANGE)
        calibration_figure(pool, out, "external_calibration", ORANGE)


def draw(run: Path):
    folds = pd.read_csv(run / "folds.csv")
    out = run / "figures"
    out.mkdir(exist_ok=True)
    fold_distributions(folds, out, "rps", "Ranked probability score")
    fold_distributions(folds, out, "auroc_alert", "AUROC of the alert")
    pool = pooled(run)
    if pool:
        roc_figure(pool, out)
        calibration_figure(pool, out)
        decision_figure(pool, out)
    if (run / "external" / "external.csv").exists():
        external_figures(run, folds, out)
    print("figures written to", out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", type=Path)
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    runs_dir = _common.OUT / "runs"
    if a.run:
        targets = [a.run]
    else:
        found = sorted((p for p in runs_dir.glob("*") if (p / "folds.csv").exists()), key=lambda p: p.stat().st_mtime)
        if not found:
            raise SystemExit(f"no recorded run in {runs_dir}")
        targets = found if a.all else found[-1:]
    for r in targets:
        draw(r)
