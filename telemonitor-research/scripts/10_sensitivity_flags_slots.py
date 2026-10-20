"""Sensitivity of two preprocessing constants — thesis ch.3 §Outliers and §Sampling plan.

1. MAD shrinkage n0 (quality.robust_z): number of Douala readings flagged as
   extreme (|z| > 3.5) per channel for n0 = 10, 20 (default) and 40.
2. eICU slot tolerance (eicu.TOLERANCE_MIN): readings kept per channel and
   samples per condition in the demonstration subset for +/- 1, 2 (default)
   and 3 hours around the 08:00 / 20:00 slots. The full benchmark can then be
   rerun on the variant that matters (scripts/06_benchmark.py).

Usage: python scripts/10_sensitivity_flags_slots.py [--no-eicu]
"""
import argparse

import _common
from telemonitor import quality as Q
from telemonitor.labels import load_thresholds
from telemonitor.windows import make_samples

ap = argparse.ArgumentParser()
ap.add_argument("--no-eicu", action="store_true")
a = ap.parse_args()

d = _common.douala()
print("=== MAD shrinkage, Douala: readings with |z| >", Q.Z_EXTREME)
for n0 in (10, 20, 40):
    z = Q.robust_z(d, n0=n0)
    counts = {ch: int((z[ch].abs() > Q.Z_EXTREME).sum()) for ch in z.columns}
    print(f"n0={n0:2d}  {counts}  total={sum(counts.values())}")

if not a.no_eicu:
    table = load_thresholds()
    print("\n=== eICU demo, slot tolerance")
    for hours in (1, 2, 3):
        e = _common.eicu_demo(tolerance=60 * hours)
        meta = make_samples(e, table).meta
        kept = {ch: int(e[ch].notna().sum()) for ch in ("sbp", "hr", "glucose")}
        print(f"+/-{hours} h  readings {kept}  samples: haemodynamic {int(meta.y_haemodynamic.notna().sum())}, "
              f"glycaemic {int(meta.y_glycaemic.notna().sum())}")
