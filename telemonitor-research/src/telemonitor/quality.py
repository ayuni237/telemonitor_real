"""Quality controls and measurement validity — thesis ch.3 §Validity and reliability.

Implements the controls of Table "tab:quality-controls" and the outlier
categories of Table "tab:outlier-categories":
  * impossible values (outside the plausible range, or an incoherent BP pair)
    are removed from the clean frame, so they reach neither features nor labels;
  * every other anomaly is flagged and kept — an extreme value may be the event.
It also provides two measurement-validity analyses: terminal-digit preference
(what kind of instrument produced the readings) and the share of labels that a
device error within the validation tolerances could change.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from scipy.stats import chisquare

from .labels import MGDL_PER_MMOLL, ThresholdTable

CHANNELS = ("sbp", "dbp", "hr", "glucose")

# Table "tab:units": plausible range per channel, in the canonical unit.
PLAUSIBLE = {"sbp": (60, 260), "dbp": (30, 160), "hr": (30, 220), "glucose": (1.0, 35.0)}

MIN_PULSE_PRESSURE = 10   # mmHg, coherence rule of tab:quality-controls
CARRY_RUN = 3             # identical consecutive values that flag carried-forward entries

# Robust z of tab:outlier-categories: (x - median) / (1.4826 MAD), MAD shrunk to the cohort.
MAD_SCALE = 1.4826
MAD_SHRINK_N0 = 20
Z_EXTREME = 3.5           # modified z-score cut-off of Iglewicz and Hoaglin

# Device-validation tolerances used to bound label uncertainty.
BP_TOLERANCE = 5.0        # mmHg, ISO 81060-2 limit on mean device error
GLU_TOLERANCE_ABS = 15.0  # mg/dL below 100 mg/dL, ISO 15197:2013
GLU_TOLERANCE_REL = 0.15  # fraction at or above 100 mg/dL, ISO 15197:2013

SLOT_ORDER = {"M": 0, "S": 1}


@dataclass
class QualityResult:
    clean: pd.DataFrame   # impossible values set to NaN, duplicates removed
    flags: pd.DataFrame   # one boolean column per control, aligned on the input index

    def summary(self) -> dict[str, int]:
        return {c: int(self.flags[c].sum()) for c in self.flags.columns}


def order_readings(df: pd.DataFrame) -> pd.DataFrame:
    """Readings sorted by patient, date and slot (morning before evening)."""
    key = df["time"].map(SLOT_ORDER) if "time" in df else 0
    return df.assign(_slot=key).sort_values(["patient", "date", "_slot"], kind="stable").drop(columns="_slot")


def check(df: pd.DataFrame) -> QualityResult:
    """Apply the entry controls to a cohort frame (columns patient, date, time and CHANNELS)."""
    df = order_readings(df)
    flags = pd.DataFrame(index=df.index)
    clean = df.copy()

    for ch in CHANNELS:
        lo, hi = PLAUSIBLE[ch]
        bad = df[ch].notna() & ~df[ch].between(lo, hi)
        flags[f"out_of_range_{ch}"] = bad
        clean.loc[bad, ch] = np.nan

    # a glucose value outside the range whose magnitude matches mg/dL or g/L
    g = df["glucose"]
    flags["unit_suspect_glucose"] = g.notna() & (
        (g > PLAUSIBLE["glucose"][1]) & (g / MGDL_PER_MMOLL).between(*PLAUSIBLE["glucose"])
        | (g < PLAUSIBLE["glucose"][0]) & (g * 1000 / (10 * MGDL_PER_MMOLL)).between(*PLAUSIBLE["glucose"]))

    # an incoherent pair has at least one wrong value, and which one cannot be known
    s, d = clean["sbp"], clean["dbp"]
    incoherent = s.notna() & d.notna() & ((s <= d) | (s - d < MIN_PULSE_PRESSURE))
    flags["incoherent_bp"] = incoherent
    clean.loc[incoherent, ["sbp", "dbp"]] = np.nan

    dup = df.duplicated(["patient", "date", "time"], keep="first") if "time" in df else df.duplicated(["patient", "date"])
    flags["duplicate"] = dup

    for ch in CHANNELS:
        flags[f"carried_forward_{ch}"] = _runs(clean, ch) >= CARRY_RUN

    z = robust_z(clean)
    for ch in CHANNELS:
        extreme = z[ch].abs() > Z_EXTREME
        nxt_ok = ~extreme.groupby(clean["patient"]).shift(-1, fill_value=True).astype(bool)
        nxt_seen = clean[ch].groupby(clean["patient"]).shift(-1).notna()
        flags[f"extreme_{ch}"] = extreme
        flags[f"contradicted_{ch}"] = extreme & nxt_seen & nxt_ok

    flags["device_unknown"] = ~df["device"].notna() if "device" in df else True
    return QualityResult(clean[~dup], flags)


def _runs(df: pd.DataFrame, ch: str) -> pd.Series:
    """Length of the run of identical consecutive values each reading belongs to."""
    x = df[ch]
    new_run = (x != x.groupby(df["patient"]).shift()) | x.isna()
    run_id = new_run.cumsum()
    length = x.groupby(run_id).transform("size")
    return length.where(x.notna(), 0)


def robust_z(df: pd.DataFrame, n0: float = MAD_SHRINK_N0) -> pd.DataFrame:
    """Per-patient robust z-score with the MAD shrunk towards the cohort MAD.

    For flagging only: it uses the patient's whole series, so it never feeds a
    feature (features use only past observations)."""
    out = pd.DataFrame(index=df.index)
    for ch in CHANNELS:
        x = df[ch]
        if x.isna().all():
            out[ch] = np.nan
            continue
        g = x.groupby(df["patient"])
        med = g.transform("median")
        dev = (x - med).abs()
        mad_i = dev.groupby(df["patient"]).transform("median")
        n_i = g.transform("count")
        mad_pooled = dev.median()
        w = n_i / (n_i + n0)
        mad = w * mad_i + (1 - w) * mad_pooled
        out[ch] = (x - med) / (MAD_SCALE * mad.replace(0, np.nan))
    return out


def terminal_digits(values) -> dict:
    """Terminal-digit distribution and its test against uniformity.

    A manual aneroid or mercury scale is graduated in 2 mmHg steps, so manual
    readings end in even digits, with an excess of zeros; an electronic display
    shows any integer. Odd digits therefore indicate an electronic device."""
    v = pd.Series(values).dropna().round().astype(int)
    counts = np.bincount(v % 10, minlength=10)
    share = counts / counts.sum()
    return {
        "n": int(counts.sum()),
        "share": {int(k): round(float(p), 4) for k, p in enumerate(share)},
        "zero": round(float(share[0]), 4),
        "odd": round(float(share[1::2].sum()), 4),
        "chi2_p_uniform": float(chisquare(counts).pvalue),
    }


def label_uncertainty(table: ThresholdTable, df: pd.DataFrame) -> dict[str, float]:
    """Share of readings whose channel level could change under a device error
    within the validation tolerance (BP: ISO 81060-2; glucose: ISO 15197)."""
    out = {}
    for ch, col in (("sbp", "sbp"), ("dbp", "dbp")):
        x = df[col].dropna().to_numpy()
        out[ch] = _ambiguous(table, ch, x, x - BP_TOLERANCE, x + BP_TOLERANCE)
    x = df["glucose"].dropna().to_numpy()
    mgdl = x * MGDL_PER_MMOLL
    tol = np.where(mgdl < 100, GLU_TOLERANCE_ABS, GLU_TOLERANCE_REL * mgdl) / MGDL_PER_MMOLL
    out["glucose"] = _ambiguous(table, "glucose", x, x - tol, x + tol)
    return out


def _ambiguous(table: ThresholdTable, ch: str, x, lo, hi) -> float:
    if len(x) == 0:
        return float("nan")
    lev = table.channel_level(ch, x)
    # levels are piecewise constant: check the interval ends and every boundary inside it
    cand = [table.channel_level(ch, lo), table.channel_level(ch, hi)]
    for r in table.rules[ch]:
        b = r.value / (MGDL_PER_MMOLL if table.units[ch] == "mg/dL" else 1.0)
        inside = (lo < b) & (b < hi)
        cand.append(np.where(inside, table.channel_level(ch, np.full(len(x), b)), lev))
    changed = np.any([c != lev for c in cand], axis=0)
    return round(float(changed.mean()), 4)
