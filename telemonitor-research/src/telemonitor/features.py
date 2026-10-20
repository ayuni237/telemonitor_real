"""Window features — thesis ch.3 §Feature Engineering.

Every feature is computed from the readings of the input window only (times in
(t - L, t]), so none can see the target. A feature that the window cannot
support is missing, never zero: a level needs one observation, a dispersion
three, and a slope three covering at least half the window (its variance
explodes when the readings are bunched in time).

Only age and sex are used as static features: they are the only patient
covariates recorded in both the development data (eICU) and the charts.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from .progress import progress
from .windows import SampleSet

CHANNELS = ("sbp", "dbp", "hr", "glucose")

MIN_FOR_DISPERSION = 3
MIN_FOR_SLOPE = 3
MIN_SLOPE_COVERAGE = 0.5   # share of the window spanned by the readings

# Fixed on clinical grounds before any result (thesis Table "tab:feature-sets").
PRIMARY = ["sbp_last", "sbp_slope", "dbp_last", "hr_last",
           "glucose_last", "glucose_slope", "glucose_n", "age"]
EXTENDED = PRIMARY + ["sbp_sd", "dbp_slope", "hr_slope", "glucose_sd",
                      "pp_last", "glucose_since", "sbp_mean", "sex_male"]
# The sixteen descriptors of the earlier notebook, kept for comparison.
DESCRIPTORS16 = [f"{c}_{d}" for c in CHANNELS for d in ("mean", "sd", "slope", "last")]
FEATURE_SETS = {"primary": PRIMARY, "extended": EXTENDED, "descriptors16": DESCRIPTORS16}


def _channel(v: np.ndarray, t: np.ndarray, t_anchor: float, L: float) -> dict:
    ok = ~np.isnan(v)
    v, t = v[ok], t[ok]
    n = len(v)
    out = {"n": n, "last": np.nan, "mean": np.nan, "sd": np.nan, "slope": np.nan, "since": np.nan}
    if n == 0:
        return out
    out.update(last=v[-1], mean=v.mean(), since=t_anchor - t[-1])
    if n >= MIN_FOR_DISPERSION:
        out["sd"] = v.std(ddof=1)
    if n >= MIN_FOR_SLOPE and (t[-1] - t[0]) >= MIN_SLOPE_COVERAGE * L:
        tc = t - t.mean()
        out["slope"] = float((tc * (v - v.mean())).sum() / (tc ** 2).sum()) * 24.0   # per day
    return out


def compute(samples: SampleSet, L: float, feature_set: str = "primary") -> pd.DataFrame:
    """Feature matrix (one row per sample) for window length L in hours."""
    names = FEATURE_SETS[feature_set]
    data = samples.data
    t_all = data["t"].to_numpy()
    vals = {c: data[c].to_numpy(dtype=float) for c in CHANNELS}
    age = data["age"].to_numpy(dtype=float) if "age" in data else np.full(len(data), np.nan)
    sex = data["sex"].to_numpy() if "sex" in data else np.full(len(data), None)
    rows = []
    for k in progress(range(len(samples)), desc=f"features {feature_set} L={L:g}h", leave=False, unit="sample"):
        w = samples.window(k, L)
        a = samples.meta.anchor.iat[k]
        f = {}
        for c in CHANNELS:
            for key, x in _channel(vals[c][w], t_all[w], t_all[a], L).items():
                f[f"{c}_{key}"] = x
        both = ~np.isnan(vals["sbp"][w]) & ~np.isnan(vals["dbp"][w])
        f["pp_last"] = (vals["sbp"][w][both][-1] - vals["dbp"][w][both][-1]) if both.any() else np.nan
        f["age"] = age[a]
        f["sex_male"] = {"M": 1.0, "F": 0.0}.get(sex[a], np.nan)
        rows.append(f)
    return pd.DataFrame(rows, index=samples.meta.index)[names]
