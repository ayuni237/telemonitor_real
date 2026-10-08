"""Repeat the descriptor ablation with a larger cohort.

At 60 patients the number of critical windows per cohort varied by an
order of magnitude between draws, which is why the earlier comparison was
inconclusive. 120 patients per cohort roughly doubles the critical count
and should reduce that variance.
"""
import numpy as np, json
from scipy import stats
from gen import generate
from features import make_windows
from train import cross_validate

SEEDS = list(range(1, 21))          # 20 cohorts
N_PATIENTS = 120                    # 2,400 simulated patients in total
CH = ["sbp","dbp","glucose","hr"]
def cols(d): return [f"{c}_{x}" for c in CH for x in d]

SETS = {"4 feat (mean only)":  ["mean"],
        "8 feat (mean+last)":  ["mean","last"],
        "12 feat (no std)":    ["mean","trend","last"],
        "16 feat (all four)":  ["mean","std","trend","last"]}

rec = {k: {"ctl":[], "rec":[], "acc":[], "pre":[]} for k in SETS}
ncrit = []

for s in SEEDS:
    df = generate(n_patients=N_PATIENTS, seed=s, covariate_effect=True)
    X, y, g = make_windows(df)
    ncrit.append(int((y==3).sum()))
    for name, d in SETS.items():
        r = cross_validate(X[cols(d)], y, g)
        rec[name]["ctl"].append(r["critical_to_low"])
        rec[name]["rec"].append(r["recall_actionable"])
        rec[name]["acc"].append(r["accuracy"])
        rec[name]["pre"].append(r["precision_actionable"])

print("="*80)
print(f"{len(SEEDS)} cohorts x {N_PATIENTS} patients = "
      f"{len(SEEDS)*N_PATIENTS:,} simulated patients")
print(f"critical windows per cohort: min {min(ncrit)}, max {max(ncrit)}, "
      f"total {sum(ncrit):,}")
print("="*80)
print(f"{'feature set':22s} {'accuracy':>9s} {'recall(act)':>12s} "
      f"{'prec':>7s} {'crit→low':>9s} {'rate':>7s}")
for k,v in rec.items():
    print(f"{k:22s} {np.mean(v['acc']):9.3f} {np.mean(v['rec']):12.3f} "
          f"{np.mean(v['pre']):7.3f} {sum(v['ctl']):9d} "
          f"{100*sum(v['ctl'])/sum(ncrit):6.2f}%")

print("\n--- paired tests against the 16-feature set ---")
ref = np.array(rec["16 feat (all four)"]["ctl"])
for k in SETS:
    if k == "16 feat (all four)": continue
    a = np.array(rec[k]["ctl"]); d = a - ref
    nz = d[d != 0]
    line = (f"{k:22s} worse in {int((d>0).sum()):2d}, better in "
            f"{int((d<0).sum()):2d}, tied {int((d==0).sum()):2d}")
    if len(nz) >= 3:
        w = stats.wilcoxon(a[d!=0], ref[d!=0])
        line += f"   p = {w.pvalue:.4f}"
    else:
        line += "   (too few non-tied)"
    print(line)

json.dump({"n_patients": N_PATIENTS, "seeds": SEEDS, "ncrit": ncrit,
           **{k:{kk:[float(x) for x in vv] for kk,vv in v.items()}
              for k,v in rec.items()}},
          open("out/verify_large.json","w"), indent=2)
