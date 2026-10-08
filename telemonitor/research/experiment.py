"""Two experiments answering the supervisor's review.

A) Do patient covariates (age, sex, BMI) improve the model?
   Run as a CONTROLLED experiment, under two conditions:
     - null    : covariates drawn independently of physiology
     - signal  : covariates carry an epidemiologically-motivated effect
   The null condition is the control. If performance improved there, the
   model would be fitting noise and the whole comparison unsound.

B) Ablation over feature subsets, to test whether the four descriptors
   were an arbitrary choice or a justified one.
"""
import numpy as np, pandas as pd, json
from gen import generate
from features import make_windows
from train import cross_validate

def run(with_cov, cov_effect, seed=42):
    df = generate(seed=seed, with_covariates=True, covariate_effect=cov_effect)
    X, y, g = make_windows(df, with_covariates=True)
    if not with_cov:
        X = X.drop(columns=["age", "sex", "bmi"])
    r = cross_validate(X, y, g)
    r["n_features"] = X.shape[1]
    return r

print("=" * 74)
print("EXPERIMENT A — patient covariates")
print("=" * 74)

rows = []
for cond, eff in [("NULL  (covariates unrelated to outcome)", False),
                  ("SIGNAL(covariates carry a real effect)", True)]:
    base = run(False, eff)
    cov  = run(True,  eff)
    rows.append((cond, base, cov))
    print(f"\n--- {cond} ---")
    print(f"{'metric':24s} {'16 feat':>9s} {'19 feat':>9s} {'delta':>9s}")
    for k in ["accuracy","recall_critical","recall_actionable",
              "precision_actionable"]:
        d = cov[k] - base[k]
        print(f"  {k:22s} {base[k]:9.3f} {cov[k]:9.3f} {d:+9.3f}")
    print(f"  {'critical_to_low':22s} {base['critical_to_low']:9d} "
          f"{cov['critical_to_low']:9d}")

print()
print("=" * 74)
print("EXPERIMENT B — ablation over feature subsets")
print("=" * 74)

df = generate(with_covariates=True, covariate_effect=True)
Xfull, y, g = make_windows(df, with_covariates=True)
CH = ["sbp","dbp","glucose","hr"]

SETS = {
  "mean only":                      [f"{c}_mean" for c in CH],
  "mean + last":                    [f"{c}_{d}" for c in CH for d in ["mean","last"]],
  "mean + std + last":              [f"{c}_{d}" for c in CH for d in ["mean","std","last"]],
  "mean + trend + last":            [f"{c}_{d}" for c in CH for d in ["mean","trend","last"]],
  "all four (current, 16)":         [f"{c}_{d}" for c in CH for d in ["mean","std","trend","last"]],
  "all four + covariates (19)":     [f"{c}_{d}" for c in CH for d in ["mean","std","trend","last"]] + ["age","sex","bmi"],
}

print(f"\n{'feature set':30s} {'n':>3s} {'acc':>7s} {'recall_act':>11s} {'prec_act':>9s} {'crit→low':>9s}")
ab = {}
for name, cols in SETS.items():
    r = cross_validate(Xfull[cols], y, g)
    ab[name] = r
    print(f"{name:30s} {len(cols):3d} {r['accuracy']:7.3f} "
          f"{r['recall_actionable']:11.3f} {r['precision_actionable']:9.3f} "
          f"{r['critical_to_low']:9d}")

json.dump({"ablation": {k: {kk: float(vv) for kk, vv in v.items()} for k, v in ab.items()}},
          open("out/experiments.json","w"), indent=2)
