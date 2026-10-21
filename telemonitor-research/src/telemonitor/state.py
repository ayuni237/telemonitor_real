"""Tracking the evolution of a patient's vital signs — thesis ch.3 §Tracking the
evolution of the patient's state.

A state is the vector of the mean of each channel (systolic, diastolic, pulse,
glucose) over a time window. The evolution of a patient is the comparison of
the current state, (t - 24 h, t], with the patient's own baseline, (t - 96 h,
t - 24 h]. No comparison measure is fixed in advance: the candidates are the
lock-step measures of the benchmark of Wang et al. (2013), plus the
Mahalanobis distance (the statistic of multivariate control charts for
individual observations, Tracy et al. 1992), and scripts/12_state_comparison.py
chooses among them.

Each measure compares only the channels present in both states. Scales and
covariances are estimated on the development data only (fit), never on the
data they are evaluated on.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from .labels import ThresholdTable
from .windows import SampleSet

CHANNELS = ("sbp", "dbp", "hr", "glucose")
CURRENT_H = 24.0                 # current state: (t - 24 h, t]
BASELINE_H = (24.0, 96.0)        # baseline: (t - 96 h, t - 24 h], the risk card's four days
SD_SHRINK_N0 = 5                 # within-patient SD shrunk to the pooled value (as quality.robust_z)
# Floor of every SD: the display resolution of the devices (1 mmHg, 1 bpm, 0.1 mmol/L), so a
# channel that never varied does not turn a one-unit change into an infinite one.
SD_FLOOR = np.array([1.0, 1.0, 1.0, 0.1])


def states(s: SampleSet, current_h: float = CURRENT_H, baseline_h: tuple[float, float] = BASELINE_H) -> pd.DataFrame:
    """One row per sample: current and baseline means per channel, the number
    of readings behind each, and the baseline standard deviation per channel."""
    data, meta = s.data, s.meta
    t_all = data["t"].to_numpy()
    vals = {c: data[c].to_numpy(float) for c in CHANNELS}
    rows = []
    for k in range(len(meta)):
        a = meta.anchor.iat[k]
        rows_p = s._rows[data.patient.iat[a]]
        t = t_all[rows_p]
        ta = t_all[a]
        cur = rows_p[(t > ta - current_h) & (t <= ta)]
        base = rows_p[(t > ta - baseline_h[1]) & (t <= ta - baseline_h[0])]
        row = {}
        for c in CHANNELS:
            vc, vb = vals[c][cur], vals[c][base]
            vc, vb = vc[np.isfinite(vc)], vb[np.isfinite(vb)]
            row[f"cur_{c}"] = vc.mean() if len(vc) else np.nan
            row[f"base_{c}"] = vb.mean() if len(vb) else np.nan
            row[f"basesd_{c}"] = vb.std(ddof=1) if len(vb) > 1 else np.nan
            row[f"nbase_{c}"] = len(vb)
        rows.append(row)
    return pd.DataFrame(rows, index=meta.index)


def _cur(st: pd.DataFrame) -> np.ndarray:
    return st[[f"cur_{c}" for c in CHANNELS]].to_numpy(float)


def _base(st: pd.DataFrame) -> np.ndarray:
    return st[[f"base_{c}" for c in CHANNELS]].to_numpy(float)


def state_level(table: ThresholdTable, st: pd.DataFrame, which: str = "base") -> np.ndarray:
    """Guideline level (0-3) of a mean state."""
    x = st[[f"{which}_{c}" for c in CHANNELS]].set_axis(list(CHANNELS), axis=1)
    return table.label(x)["y"].to_numpy()


@dataclass
class Scales:
    """Scales estimated on development states: between-patient SD of each
    channel (cohort z-scores), pooled within-patient SD (for the shrinkage of
    each patient's own SD), and the pooled within-patient covariance of the
    current-minus-baseline difference (Mahalanobis)."""
    cohort_mean: np.ndarray = field(default_factory=lambda: np.zeros(len(CHANNELS)))
    cohort_sd: np.ndarray = field(default_factory=lambda: np.ones(len(CHANNELS)))
    within_sd: np.ndarray = field(default_factory=lambda: np.ones(len(CHANNELS)))
    diff_cov: np.ndarray = field(default_factory=lambda: np.eye(len(CHANNELS)))

    @classmethod
    def fit(cls, st: pd.DataFrame) -> "Scales":
        base = _base(st)
        cohort = np.nanstd(base, axis=0, ddof=1)
        sd = st[[f"basesd_{c}" for c in CHANNELS]].to_numpy(float)
        within = np.sqrt(np.nanmean(sd ** 2, axis=0))
        d = _cur(st) - base
        df = pd.DataFrame(d, columns=CHANNELS)
        cov = df.cov(min_periods=10).to_numpy()            # pairwise complete
        cov = np.where(np.isfinite(cov), cov, 0.0)
        cov[np.diag_indices_from(cov)] = np.where(np.diag(cov) > 0, np.diag(cov), within ** 2)
        return cls(np.nanmean(base, axis=0), np.maximum(cohort, SD_FLOOR), np.maximum(within, SD_FLOOR), cov)


    def to_json(self) -> dict:
        return {k: np.asarray(getattr(self, k)).round(6).tolist()
                for k in ("cohort_mean", "cohort_sd", "within_sd", "diff_cov")}

    @classmethod
    def from_json(cls, d: dict) -> "Scales":
        return cls(**{k: np.asarray(v, float) for k, v in d.items()})


# ----------------------------------------------------------------- measures
def _pairs(st: pd.DataFrame):
    c, b = _cur(st), _base(st)
    return c, b, np.isfinite(c) & np.isfinite(b)


def _rowwise(fn, st: pd.DataFrame, min_channels: int) -> np.ndarray:
    c, b, ok = _pairs(st)
    out = np.full(len(st), np.nan)
    for i in range(len(st)):
        m = ok[i]
        if m.sum() >= min_channels:
            out[i] = fn(c[i, m], b[i, m], m, i)
    return out


def cosine_distance(st, sc, min_channels=2):
    """1 - cos(current, baseline) on raw values: insensitive to a common change
    of magnitude (a 50 % rise of every channel gives 0)."""
    def f(x, y, m, i):
        n = np.linalg.norm(x) * np.linalg.norm(y)
        return 1 - float(x @ y) / n if n > 0 else np.nan
    return _rowwise(f, st, min_channels)


def cosine_centred_distance(st, sc, min_channels=2):
    """Cosine on cohort z-scores (centred on the development mean): compares
    the direction of the deviation, still not its size."""
    def f(x, y, m, i):
        a, b = (x - sc.cohort_mean[m]) / sc.cohort_sd[m], (y - sc.cohort_mean[m]) / sc.cohort_sd[m]
        n = np.linalg.norm(a) * np.linalg.norm(b)
        return 1 - float(a @ b) / n if n > 0 else np.nan
    return _rowwise(f, st, min_channels)


def euclidean_raw(st, sc, min_channels=1):
    """Euclidean distance in raw units (mmHg and mmol/L mixed)."""
    return _rowwise(lambda x, y, m, i: float(np.linalg.norm(x - y)), st, min_channels)


def euclidean_cohort_z(st, sc, min_channels=1):
    """Euclidean distance on cohort z-scores (each channel / between-patient SD)."""
    return _rowwise(lambda x, y, m, i: float(np.linalg.norm((x - y) / sc.cohort_sd[m])), st, min_channels)


def _patient_sd(st: pd.DataFrame, sc: Scales) -> np.ndarray:
    """Patient's own baseline SD shrunk to the pooled within-patient SD."""
    sd = st[[f"basesd_{c}" for c in CHANNELS]].to_numpy(float)
    n = st[[f"nbase_{c}" for c in CHANNELS]].to_numpy(float)
    w = np.clip(n - 1, 0, None) / (np.clip(n - 1, 0, None) + SD_SHRINK_N0)
    sd = np.where(np.isfinite(sd), sd, sc.within_sd)
    return np.maximum(np.sqrt(w * sd ** 2 + (1 - w) * sc.within_sd ** 2), SD_FLOOR)


def euclidean_patient_z(st, sc, min_channels=1):
    """Euclidean distance on the patient's own variability: each change divided
    by the patient's within-person SD (the idea of the reference change value)."""
    psd = _patient_sd(st, sc)
    return _rowwise(lambda x, y, m, i: float(np.linalg.norm((x - y) / psd[i, m])), st, min_channels)


def manhattan_patient_z(st, sc, min_channels=1):
    psd = _patient_sd(st, sc)
    return _rowwise(lambda x, y, m, i: float(np.abs((x - y) / psd[i, m]).sum()), st, min_channels)


def chebyshev_patient_z(st, sc, min_channels=1):
    psd = _patient_sd(st, sc)
    return _rowwise(lambda x, y, m, i: float(np.abs((x - y) / psd[i, m]).max()), st, min_channels)


def mahalanobis(st, sc, min_channels=1):
    """Mahalanobis distance of the change, with the pooled within-patient
    covariance of changes: correlated channels (systolic and diastolic) are
    not counted twice."""
    def f(x, y, m, i):
        cov = sc.diff_cov[np.ix_(m, m)]
        d = x - y
        try:
            return float(np.sqrt(d @ np.linalg.solve(cov, d)))
        except np.linalg.LinAlgError:
            return np.nan
    return _rowwise(f, st, min_channels)


MEASURES = {
    "cosine": cosine_distance,
    "cosine_centred": cosine_centred_distance,
    "euclidean_raw": euclidean_raw,
    "euclidean_cohort_z": euclidean_cohort_z,
    "euclidean_patient_z": euclidean_patient_z,
    "manhattan_patient_z": manhattan_patient_z,
    "chebyshev_patient_z": chebyshev_patient_z,
    "mahalanobis": mahalanobis,
}


def per_channel(st_row: pd.Series, sc: Scales) -> dict:
    """Per-channel evolution for display: change in units and in the
    patient's own SD, with its direction."""
    st = st_row.to_frame().T
    psd = _patient_sd(st, sc)[0]
    out = {}
    for j, c in enumerate(CHANNELS):
        cur, base = float(st[f"cur_{c}"].iloc[0]), float(st[f"base_{c}"].iloc[0])
        if np.isfinite(cur) and np.isfinite(base):
            out[c] = {"current": round(cur, 2), "baseline": round(base, 2), "change": round(cur - base, 2),
                      "change_sd": round((cur - base) / psd[j], 2)}
    return out


def evolution(times, values: dict, sc: Scales, measure: str | None,
              current_h: float = CURRENT_H, baseline_h: tuple[float, float] = BASELINE_H) -> dict:
    """Evolution of one patient for the risk service: current state against
    baseline at the last reading, per channel and, once a measure has been
    selected by the benchmark, as one distance. `times` in hours, `values`
    channel -> array aligned on times."""
    t = np.asarray(times, float)
    ta = t.max()
    cur = (t > ta - current_h) & (t <= ta)
    base = (t > ta - baseline_h[1]) & (t <= ta - baseline_h[0])
    row = {}
    for c in CHANNELS:
        v = np.asarray(values.get(c, np.full(len(t), np.nan)), float)
        vc, vb = v[cur & np.isfinite(v)], v[base & np.isfinite(v)]
        row[f"cur_{c}"] = vc.mean() if len(vc) else np.nan
        row[f"base_{c}"] = vb.mean() if len(vb) else np.nan
        row[f"basesd_{c}"] = vb.std(ddof=1) if len(vb) > 1 else np.nan
        row[f"nbase_{c}"] = len(vb)
    st = pd.DataFrame([row])
    out = {"channels": per_channel(st.iloc[0], sc), "measure": measure, "distance": None}
    if measure is not None and out["channels"]:
        d = MEASURES[measure](st, sc, 1)[0]
        out["distance"] = None if not np.isfinite(d) else round(float(d), 3)
    return out
