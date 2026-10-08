"""Does the main ablation claim survive a paired test over 30 cohorts?

The claim to be checked: descriptors beyond the channel means reduce the
rate at which critical windows are assigned to non-alerting levels.
"""
import numpy as np, json
from scipy import stats
from gen import generate
from features import make_windows
from train import cross_validate

SEEDS = list(range(1, 31))
CH = ["sbp","dbp","glucose","hr"]
def cols(d): return [f"{c}_{x}" for c in CH for x in d]

SETS = {"4 feat (mean only)":        ["mean"],
        "8 feat (mean+last)":        ["mean","last"],
        "16 feat (all four)":        ["mean","std","trend","last"]}

rec = {k: {"ctl":[], "rec":[], "acc":[]} for k in SETS}
ncrit = []
for s in SEEDS:
    df = generate(seed=s, with_covariates=False, covariate_effect=True)
    X, y, g = make_windows(df)
    ncrit.append(int((y==3).sum()))
    for name, d in SETS.items():
        r = cross_validate(X[cols(d)], y, g)
        rec[name]["ctl"].append(r["critical_to_low"])
        rec[name]["rec"].append(r["recall_actionable"])
        rec[name]["acc"].append(r["accuracy"])

print("="*78)
print(f"PAIRED, {len(SEEDS)} cohorts, {sum(ncrit)} critical windows")
print("="*78)
for k,v in rec.items():
    print(f"{k:22s} acc {np.mean(v['acc']):.3f}  rec {np.mean(v['rec']):.3f}  "
          f"crit→low {sum(v['ctl']):4d}  ({100*sum(v['ctl'])/sum(ncrit):.2f}%)  "
          f"cohorts>0: {int((np.array(v['ctl'])>0).sum())}")

m = np.array(rec["4 feat (mean only)"]["ctl"])
f = np.array(rec["16 feat (all four)"]["ctl"])
d = m - f
print(f"\nmean-only worse in {int((d>0).sum())} cohorts, better in {int((d<0).sum())}, "
      f"tied in {int((d==0).sum())}")
nz = d[d!=0]
if len(nz) >= 3:
    w = stats.wilcoxon(m[d!=0], f[d!=0])
    print(f"Wilcoxon (n={len(nz)} non-tied): statistic={w.statistic:.1f}, p={w.pvalue:.4f}")

print("\nper-cohort (mean-only / 16-feat), non-zero only:")
for s,x,yv in zip(SEEDS, m, f):
    if x or yv: print(f"   seed {s:3d}: {x:4d} / {yv:4d}")

json.dump({k:{kk:[float(x) for x in vv] for kk,vv in v.items()} for k,v in rec.items()},
          open("out/verify_meanonly.json","w"), indent=2)
