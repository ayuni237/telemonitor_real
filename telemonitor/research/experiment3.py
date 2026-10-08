"""Wider replication. Five cohorts proved too few: the safety metric was
driven entirely by one difficult cohort, which cannot support a claim.
Fifteen cohorts give a more honest view of how often that occurs."""
import numpy as np, json
from gen import generate
from features import make_windows
from train import cross_validate

SEEDS = [42,101,202,303,404,505,606,707,808,909,111,222,333,555,777]
CH = ["sbp","dbp","glucose","hr"]

SETS = {
  "mean only":             (["mean"], False),
  "mean + last":           (["mean","last"], False),
  "mean + trend + last":   (["mean","trend","last"], False),
  "all four (current)":    (["mean","std","trend","last"], False),
  "all four + covariates": (["mean","std","trend","last"], True),
}
def cols(d, cov): return [f"{c}_{x}" for c in CH for x in d] + (["age","sex","bmi"] if cov else [])

res = {k: {"acc":[], "rec":[], "pre":[], "ctl":[], "ncrit":[]} for k in SETS}

for s in SEEDS:
    df = generate(seed=s, with_covariates=True, covariate_effect=True)
    X, y, g = make_windows(df, with_covariates=True)
    ncrit = int((y == 3).sum())
    for name,(d,cov) in SETS.items():
        r = cross_validate(X[cols(d,cov)], y, g)
        res[name]["acc"].append(r["accuracy"])
        res[name]["rec"].append(r["recall_actionable"])
        res[name]["pre"].append(r["precision_actionable"])
        res[name]["ctl"].append(r["critical_to_low"])
        res[name]["ncrit"].append(ncrit)

print("="*90)
print(f"{len(SEEDS)} cohorts, patient-disjoint 5-fold each, covariates carrying a real effect")
print("="*90)
print(f"{'feature set':24s} {'accuracy':>15s} {'recall(act)':>15s} "
      f"{'crit→low total':>15s} {'cohorts w/ >0':>14s}")
for k,v in res.items():
    a,r,c = np.array(v["acc"]), np.array(v["rec"]), np.array(v["ctl"])
    print(f"{k:24s} {a.mean():6.3f} ±{a.std():.3f} {r.mean():8.3f} ±{r.std():.3f} "
          f"{int(c.sum()):15d} {int((c>0).sum()):11d}/{len(SEEDS)}")

tot_crit = sum(res["mean only"]["ncrit"])
print(f"\ntotal critical windows across all cohorts: {tot_crit}")
print("\ncrit→low as a rate (lower is safer):")
for k,v in res.items():
    print(f"  {k:24s} {sum(v['ctl'])/tot_crit*100:6.2f}%")

json.dump({k:{kk:[float(x) for x in vv] for kk,vv in v.items()} for k,v in res.items()},
          open("out/ablation_15cohorts.json","w"), indent=2)
