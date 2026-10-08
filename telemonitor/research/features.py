"""Sliding-window feature extraction for TeleMonitor.

Window: W consecutive readings of one patient, ordered in time.
Channels: sbp, dbp, glucose, hr.
Descriptors per channel: mean, std (population, ddof=0), OLS trend, last value.
=> 4 channels x 4 descriptors = 16 features.

A channel with fewer than MIN_REAL observed values inside the window is
declared unavailable and ALL FOUR of its descriptors are emitted as NaN.
XGBoost learns a default branch direction for NaN, so an absent channel is
handled without imputing a value that was never measured.
"""
import numpy as np, pandas as pd

W, MIN_REAL = 7, 3
CHANNELS = ['sbp', 'dbp', 'glucose', 'hr']
DESCRIPTORS = ['mean', 'std', 'trend', 'last']
FEATURE_NAMES = [f'{c}_{d}' for c in CHANNELS for d in DESCRIPTORS]

_T = np.arange(W, dtype=float)
_TC = _T - _T.mean()
_DEN = float((_TC ** 2).sum())        # 28.0 for W=7


def _locf(v):
    """Forward fill, then backfill the leading gap. Operates inside one window."""
    s = pd.Series(v, dtype=float)
    return s.ffill().bfill().to_numpy()


def _descriptors(v):
    """v: length-W array for one channel, possibly containing NaN."""
    n_real = int(np.isfinite(v).sum())
    if n_real < MIN_REAL:
        return [np.nan] * 4
    x = _locf(v)
    mean = x.mean()
    std = x.std(ddof=0)
    trend = float((_TC * (x - mean)).sum() / _DEN)   # OLS slope, closed form
    return [mean, std, trend, x[-1]]


def level(sbp, dbp, glu):
    """ESH/WHO threshold labelling. NaN never triggers a comparison."""
    s = -1 if pd.isna(sbp) else sbp
    d = -1 if pd.isna(dbp) else dbp
    g = -1 if pd.isna(glu) else glu
    if s >= 180 or d >= 110 or g >= 14: return 3
    if s >= 160 or d >= 100 or g >= 11: return 2
    if s >= 140 or d >= 90  or g >= 8:  return 1
    return 0


def make_windows(df, horizon=1):
    """horizon=1 -> FORECAST: features from readings t-W+1..t, label from t+1.
       horizon=0 -> NOWCAST: label from reading t (leaks; used only for the
                             leakage demonstration in the paper)."""
    X, y, groups, meta = [], [], [], []
    for pid, g in df.groupby('patient'):
        g = g.sort_values('seq').reset_index(drop=True)
        arr = {c: g[c].to_numpy(dtype=float) for c in CHANNELS}
        n = len(g)
        for i in range(n - W + 1 - horizon):
            win = slice(i, i + W)
            feats = []
            for c in CHANNELS:
                feats += _descriptors(arr[c][win])
            # a window is retained only if the three vital channels are present
            if any(np.isnan(feats[j]) for c in ('sbp', 'dbp', 'hr')
                   for j in [CHANNELS.index(c) * 4]):
                continue
            t = i + W - 1 + horizon
            X.append(feats)
            y.append(level(arr['sbp'][t], arr['dbp'][t], arr['glucose'][t]))
            groups.append(pid)
            meta.append(dict(patient=pid, target_row=t,
                             glucose_observed=not np.isnan(feats[8])))
    return (np.asarray(X, dtype=float), np.asarray(y, dtype=int),
            np.asarray(groups), pd.DataFrame(meta))
