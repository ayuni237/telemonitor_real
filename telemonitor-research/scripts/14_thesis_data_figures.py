"""Data behind the data figures of the thesis — ch.3 §Data collection, ch.4 §Data results.

Writes pgfplots-ready CSV files to memoire/figures/data/ (or --out):
  douala_readings_timeline.csv  one row per Douala reading: patient renumbered 1..32 by first
                                reading, day since the patient's first reading (+0.5 in the
                                evening), overall level, glucose present. Patient-level:
                                ignored by git (figures/data/.gitignore).
  values_<channel>.csv          share of readings per value bin, Douala and eICU demo
  transitions_<task>_<data>.csv level of the target against the level of the anchor reading
                                (row shares and counts), the basis of the persistence baseline
  riley_<task>_<data>.csv       parameters allowed by the criteria of Riley et al. against the
                                anticipated C statistic, samples taken as independent and
                                effective sample size (as scripts/04_sample_size.py)
and prints the numbers quoted in the text.

Usage: python scripts/14_thesis_data_figures.py [--out <dir>]
"""
import argparse

import numpy as np
import pandas as pd

import _common
from telemonitor import sample_size as S
from telemonitor.labels import load_thresholds
from telemonitor.windows import add_time, make_samples

BINS = {"sbp": np.arange(60, 270, 10), "dbp": np.arange(30, 170, 10), "glucose": np.arange(1, 32, 1)}
TASKS = {"haemodynamic": "y_haemodynamic", "glycaemic": "y_glycaemic"}

ap = argparse.ArgumentParser()
ap.add_argument("--out", default=str(_common.ROOT.parent / "memoire" / "figures" / "data"))
a = ap.parse_args()
out = _common.Path(a.out)
out.mkdir(parents=True, exist_ok=True)
(out / ".gitignore").write_text("# patient-level rows of the Douala charts: never commit\ndouala_readings_*.csv\n")

table = load_thresholds()
data = {"douala": _common.douala(), "eicu": _common.eicu_demo(require_heart_rate=True)}

# ---- 1. timeline of the Douala readings
d = add_time(data["douala"])
lab = table.label(d)
d = d.assign(level=lab["y"].fillna(-1).astype(int), has_glucose=d["glucose"].notna().astype(int))
first = d.groupby("patient")["t"].min()
order = {p: i + 1 for i, p in enumerate(first.sort_values().index)}
d["pid"] = d["patient"].map(order)
d["day"] = (d["t"] - d["patient"].map(first)) / 24.0
d[["pid", "day", "level", "has_glucose"]].sort_values(["pid", "day"]).to_csv(
    out / "douala_readings_timeline.csv", index=False)
span = d.groupby("pid")["day"].max()
print(f"timeline: {d.pid.nunique()} patients, follow-up {span.median():.1f} days median "
      f"(range {span.min():.1f}-{span.max():.1f})")

# ---- 2. value distributions
for ch, edges in BINS.items():
    rows = {"lo": edges[:-1], "hi": edges[1:], "mid": (edges[:-1] + edges[1:]) / 2}
    for name, df in data.items():
        x = df[ch].dropna().clip(edges[0], edges[-1] - 1e-9)
        rows[name] = np.histogram(x, bins=edges)[0] / len(x)
        print(f"{ch:8s} {name:7s} n={len(x):5d} median={df[ch].median():.1f} "
              f"IQR={df[ch].quantile(.25):.1f}-{df[ch].quantile(.75):.1f}")
    pd.DataFrame(rows).round(5).to_csv(out / f"values_{ch}.csv", index=False)

# ---- 3. transitions between the anchor reading and the target
for name, df in data.items():
    s = make_samples(df, table)
    lab = table.label(s.data)
    for task, col in TASKS.items():
        a_lev = lab[col].to_numpy()[s.meta["anchor"].to_numpy()]
        t_lev = s.meta[col].to_numpy()
        ok = ~(np.isnan(a_lev) | np.isnan(t_lev))
        m = pd.crosstab(a_lev[ok].astype(int), t_lev[ok].astype(int)).reindex(
            index=range(4), columns=range(4), fill_value=0)
        share = m.div(m.sum(axis=1).replace(0, np.nan), axis=0)
        long = [{"anchor": i, "target": j, "count": int(m.iat[i, j]),
                 "share": round(float(share.iat[i, j]), 4) if m.iloc[i].sum() else 0.0}
                for i in range(4) for j in range(4)]
        pd.DataFrame(long).to_csv(out / f"transitions_{task}_{name}.csv", index=False)
        same = np.trace(m.to_numpy()) / m.to_numpy().sum()
        alert_kept = m.iloc[2:, 2:].to_numpy().sum() / max(m.iloc[2:].to_numpy().sum(), 1)
        new_alert = m.iloc[:2, 2:].to_numpy().sum() / max(m.iloc[:2].to_numpy().sum(), 1)
        print(f"transitions {task:12s} {name:7s} pairs={ok.sum():5d} same level={same:.3f} "
              f"alert stays alert={alert_kept:.3f} non-alert becomes alert={new_alert:.3f}")

        # ---- 4. parameters allowed against the anticipated C statistic
        x = s.meta.dropna(subset=[col])
        yb = (x[col] >= 2).astype(int).to_numpy()
        g = x.group.to_numpy()
        prev = yb.mean()
        deff, neff = S.effective_n(g, S.icc_oneway(yb, g))
        rows = []
        for c in np.round(np.arange(0.60, 0.851, 0.025), 3):
            r2 = S.cstat_to_r2cs(c, prev)
            rows.append({"c": c, "independent": S.max_parameters(len(yb), r2, prev),
                         "effective": S.max_parameters(neff, r2, prev)})
        pd.DataFrame(rows).to_csv(out / f"riley_{task}_{name}.csv", index=False)
print("written to", out)
