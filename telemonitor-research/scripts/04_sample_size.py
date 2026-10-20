"""Step 4 — sample size and parameter budget (Riley et al.), Douala and eICU demo.

Reproduces thesis Table "tab:sample-size" and the development budget:
  * Douala: effective sample 72 (haemodynamic) and 53 (glycaemic); 0-1 parameter allowed;
  * patients needed for 8 parameters (about 215 and 170 at C = 0.75);
  * eICU demo: effective sample about 1240 (haemodynamic) -> 10-24 parameters; about 250 (glycaemic).
Also checks the port against the published example of pmsampsize (n = 662).
Usage: python scripts/04_sample_size.py [--no-eicu] [--no-heart-rate]
"""
import argparse

import _common
from telemonitor import sample_size as S
from telemonitor.labels import load_thresholds
from telemonitor.windows import make_samples

ap = argparse.ArgumentParser()
ap.add_argument("--no-eicu", action="store_true")
ap.add_argument("--no-heart-rate", action="store_true", help="eICU without vitalPeriodic")
a = ap.parse_args()

ref = S.riley_binary(0.288, 24, 0.174)
print("parity with pmsampsize example (expected 623 / 662 / 221 -> 662):",
      ref["n1_shrinkage"], ref["n2_r2_difference"], ref["n3_overall_risk"], "->", ref["n_required"])

table = load_thresholds()
datasets = {"Douala": _common.douala()}
if not a.no_eicu:
    datasets["eICU demo"] = _common.eicu_demo(require_heart_rate=not a.no_heart_rate)

for name, df in datasets.items():
    meta = make_samples(df, table).meta
    print(f"\n=== {name}")
    for task in ("y_haemodynamic", "y_glycaemic"):
        x = meta.dropna(subset=[task])
        yb = (x[task] >= 2).astype(int).to_numpy()
        g = x.group.to_numpy()
        prev = yb.mean()
        icc = S.icc_oneway(yb, g)
        deff, neff = S.effective_n(g, icc)
        n3 = S.riley_binary(0.1, 1, prev)["n3_overall_risk"]
        print(f"{task}: samples={len(yb)} patients={len(set(g))} prevalence={prev:.3f} ICC={icc:.3f} "
              f"DEFF={deff:.2f} n_eff={neff:.0f} n_overall_risk={n3}")
        spp = len(yb) / len(set(g))
        for c in (0.65, 0.70, 0.75, 0.80):
            r2 = S.cstat_to_r2cs(c, prev)
            need8 = S.riley_binary(r2, 8, prev)["n_required"]
            print(f"   C={c:.2f} R2cs={r2:.3f}  parameters: independent {S.max_parameters(len(yb), r2, prev):2d}, "
                  f"effective {S.max_parameters(neff, r2, prev):2d}  | patients for 8 parameters ~{need8 * deff / spp:.0f}")
