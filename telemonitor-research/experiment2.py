"""Repeated-seed version. A single run cannot distinguish a real effect
from cohort-sampling noise, so every configuration is evaluated over
several independently generated cohorts and reported as mean +/- sd."""
import numpy as np, pandas as pd, json
from gen import generate
from features import make_windows
from train import cross_validate

SEEDS = [42, 101, 202, 303, 404]
CH = ["sbp", "dbp", "glucose", "hr"]

def cols_for(descs, cov=False):
    c = [f"{ch}_{d}" for ch in CH for d in descs]
    return c + (["age","sex","bmi"] if cov else [])

SETS = {
  "mean only":                  (["mean"], False),
  "mean + last":                (["mean","last"], False),
  "mean + std + last":          (["mean","std","last"], False),
  "mean + trend + last":        (["mean","trend","last"], False),
  "all four (current)":         (["mean","std","trend","last"], False),
  "all four + covariates":      (["mean","std","trend","last"], True),
}

def evaluate(cov_effect):
    acc = {k: [] for k in SETS}
    rec = {k: [] for k in SETS}
    pre = {k: [] for k in SETS}
    ctl = {k: [] for k in SETS}
    for s in SEEDS:
        df = generate(seed=s, with_covariates=True, covariate_effect=cov_effect)
        X, y, g = make_windows(df, with_covariates=True)
        for name, (descs, cov) in SETS.items():
            r = cross_validate(X[cols_for(descs, cov)], y, g)
            acc[name].append(r["accuracy"])
            rec[name].append(r["recall_actionable"])
            pre[name].append(r["precision_actionable"])
            ctl[name].append(r["critical_to_low"])
    return acc, rec, pre, ctl

for label, eff in [("COVARIATES CARRY NO EFFECT (control)", False),
                   ("COVARIATES CARRY A REAL EFFECT", True)]:
    acc, rec, pre, ctl = evaluate(eff)
    print("=" * 78)
    print(label + f"   —  {len(SEEDS)} cohorts, patient-disjoint 5-fold each")
    print("=" * 78)
    print(f"{'feature set':26s} {'accuracy':>16s} {'recall (action.)':>18s} "
          f"{'precision':>16s} {'crit→low':>9s}")
    for name in SETS:
        a, r, p = np.array(acc[name]), np.array(rec[name]), np.array(pre[name])
        print(f"{name:26s} {a.mean():7.3f} ±{a.std():.3f} "
              f"{r.mean():10.3f} ±{r.std():.3f} "
              f"{p.mean():8.3f} ±{p.std():.3f} {int(np.sum(ctl[name])):9d}")
    print()
    json.dump({k: {"accuracy": acc[k], "recall": rec[k], "precision": pre[k],
                   "crit_to_low": ctl[k]} for k in SETS},
              open(f"out/ablation_{'signal' if eff else 'control'}.json","w"), indent=2)
