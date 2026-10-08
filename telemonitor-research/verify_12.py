"""Is the 12-feature set genuinely safer than 16, or is the difference
sampling noise?

The comparison is PAIRED: both feature sets are evaluated on the same
cohort, so between-cohort variation cancels. This is far more powerful
than comparing marginal means, which is what the earlier run did.
"""
import numpy as np, json
from scipy import stats
from gen import generate
from features import make_windows
from train import cross_validate

SEEDS = list(range(1, 31))          # 30 cohorts
CH = ["sbp","dbp","glucose","hr"]

A_NAME, A = "12 feat (mean+trend+last)", ["mean","trend","last"]
B_NAME, B = "16 feat (all four)",        ["mean","std","trend","last"]

def cols(d): return [f"{c}_{x}" for c in CH for x in d]

rec = {A_NAME: {"ctl":[], "rec":[], "acc":[], "pre":[]},
       B_NAME: {"ctl":[], "rec":[], "acc":[], "pre":[]}}
ncrit = []

for s in SEEDS:
    df = generate(seed=s, with_covariates=False, covariate_effect=True)
    X, y, g = make_windows(df)
    ncrit.append(int((y == 3).sum()))
    for name, d in [(A_NAME, A), (B_NAME, B)]:
        r = cross_validate(X[cols(d)], y, g)
        rec[name]["ctl"].append(r["critical_to_low"])
        rec[name]["rec"].append(r["recall_actionable"])
        rec[name]["acc"].append(r["accuracy"])
        rec[name]["pre"].append(r["precision_actionable"])

a = np.array(rec[A_NAME]["ctl"]); b = np.array(rec[B_NAME]["ctl"])
diff = b - a                        # positive => 12-feat safer

print("="*76)
print(f"PAIRED COMPARISON over {len(SEEDS)} cohorts")
print("="*76)
for name in (A_NAME, B_NAME):
    v = rec[name]
    print(f"{name:28s} acc {np.mean(v['acc']):.3f}  "
          f"rec {np.mean(v['rec']):.3f}  "
          f"prec {np.mean(v['pre']):.3f}  "
          f"crit→low total {sum(v['ctl'])}")

print(f"\ntotal critical windows: {sum(ncrit)}")
print(f"\ncohorts where 12-feat had FEWER errors : {int((diff>0).sum())}")
print(f"cohorts where 16-feat had FEWER errors : {int((diff<0).sum())}")
print(f"cohorts tied (usually both zero)       : {int((diff==0).sum())}")

nz = diff[diff != 0]
if len(nz) >= 3:
    w = stats.wilcoxon(a[diff!=0], b[diff!=0])
    print(f"\nWilcoxon signed-rank on non-tied cohorts (n={len(nz)}): "
          f"statistic={w.statistic:.1f}, p={w.pvalue:.3f}")
else:
    print(f"\nOnly {len(nz)} non-tied cohorts — too few for a signed-rank test.")

print("\nper-cohort errors (12 feat / 16 feat), non-zero only:")
for s, x, yv in zip(SEEDS, a, b):
    if x or yv: print(f"   seed {s:3d}:  {x:3d} / {yv:3d}")

json.dump({"seeds": SEEDS, "ncrit": ncrit,
           A_NAME: rec[A_NAME], B_NAME: rec[B_NAME]},
          open("out/verify_12_vs_16.json","w"), indent=2)
