"""Step 1 — labelling rules compared on the Douala charts.

Reproduces the comparison of the earlier rule (notebook: ESH grades + glucose 8/11/14, no lower
thresholds) with the sourced rule of thesis Table "tab:label-thresholds", and the effect of using
all NEWS2 low-pressure bands instead of the single red score (103 readings re-graded).
Output: printed tables and out/label_rules.csv
"""
import numpy as np
import pandas as pd

import _common
from telemonitor.labels import load_thresholds

d = _common.douala(clean=False)


def old_rule(r):
    """Rule of the earlier notebook and features.py (before the thesis correction)."""
    s = r.sbp if pd.notna(r.sbp) else -1
    di = r.dbp if pd.notna(r.dbp) else -1
    g = r.glucose if pd.notna(r.glucose) else -1
    if s >= 180 or di >= 110 or g >= 14: return 3
    if s >= 160 or di >= 100 or g >= 11: return 2
    if s >= 140 or di >= 90 or g >= 8: return 1
    return 0


def all_news2_low_bands(sbp):
    """NEWS2 systolic bands used alone (the rejected reading): <=90 -> 3, 91-100 -> 2, 101-110 -> 1."""
    return np.select([sbp <= 90, sbp <= 100, sbp <= 110], [3, 2, 1], 0)


t = load_thresholds()
lab = t.label(d)
cap = t.variant("cap_severe_hyperglycaemia").label(d)
d["old"] = d.apply(old_rule, axis=1)
d["new"], d["new_capped"] = lab["y"], cap["y"]
d["y_haemodynamic"], d["y_glycaemic"] = lab["y_haemodynamic"], lab["y_glycaemic"]
# ESH grades alone (high side), then with every NEWS2 low band added
bp = d.sbp.notna() & d.dbp.notna()
esh = np.select([(d.sbp >= 180) | (d.dbp >= 110), (d.sbp >= 160) | (d.dbp >= 100), (d.sbp >= 140) | (d.dbp >= 90)],
                [3, 2, 1], 0)
with_bands = np.maximum(esh, all_news2_low_bands(d.sbp.fillna(999)))

pct = lambda s: (s.dropna().value_counts(normalize=True).sort_index() * 100).round(1).to_dict()
print("earlier rule       ", pct(d.old))
print("sourced rule       ", pct(d.new))
print("capped variant     ", pct(d.new_capped))
print("haemodynamic label ", pct(d.y_haemodynamic))
print("glycaemic label    ", pct(d.y_glycaemic))
print("readings re-graded if every NEWS2 low band were used:", int(((with_bands > esh) & bp).sum()))
print("\ncross-table, earlier rule (rows) vs sourced rule (columns)")
print(pd.crosstab(d.old, d.new))
glu = d.glucose.notna()
print("\nalert (level >= 2) with glucose measured / absent:",
      round(float((d.new[glu] >= 2).mean()), 3), round(float((d.new[~glu] >= 2).mean()), 3))
d[["patient", "date", "time", "sbp", "dbp", "hr", "glucose", "old", "new", "new_capped"]].to_csv(
    _common.OUT / "label_rules.csv", index=False)
