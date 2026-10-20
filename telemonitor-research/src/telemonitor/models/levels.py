"""From forecast values to level probabilities — thesis ch.3 §Formulation, §Risk score.

A value forecast x_hat with error spread sigma gives, for each channel, the
probability of each severity level by integrating the normal error distribution
over the intervals of the threshold table. Within a condition the level is the
worst channel, so P(level <= k) is the product over channels of P(s_c <= k),
under the assumption, stated in the thesis, that channel errors are
independent given the inputs.
"""
from __future__ import annotations

import numpy as np
from scipy.stats import norm

from ..labels import INPUT_UNITS, MGDL_PER_MMOLL, ThresholdTable

N_LEVELS = 4


def _breakpoints(table: ThresholdTable, channel: str) -> np.ndarray:
    """Sorted thresholds of a channel, in the input unit of the readings."""
    f = MGDL_PER_MMOLL if (table.units[channel], INPUT_UNITS[channel]) == ("mg/dL", "mmol/L") else 1.0
    return np.unique([r.value / f for r in table.rules[channel]])


def channel_level_proba(table: ThresholdTable, channel: str, mu: np.ndarray, sigma: float) -> np.ndarray:
    """(n, 4) probabilities of each level of one channel."""
    mu = np.asarray(mu, float)
    b = _breakpoints(table, channel)
    edges = np.concatenate([[-np.inf], b, [np.inf]])
    mids = np.concatenate([[b[0] - 1.0], (b[:-1] + b[1:]) / 2, [b[-1] + 1.0]])
    lev = table.channel_level(channel, mids).astype(int)
    out = np.zeros((len(mu), N_LEVELS))
    s = max(float(sigma), 1e-6)
    for lo, hi, k in zip(edges[:-1], edges[1:], lev):
        out[:, k] += norm.cdf((hi - mu) / s) - norm.cdf((lo - mu) / s)
    return out


def condition_level_proba(per_channel: list[np.ndarray]) -> np.ndarray:
    """Worst-channel combination: P(max <= k) = prod_c P(s_c <= k)."""
    cdf = np.prod([np.cumsum(p, axis=1) for p in per_channel], axis=0)
    proba = np.diff(np.concatenate([np.zeros((cdf.shape[0], 1)), cdf], axis=1), axis=1)
    return np.clip(proba, 0, 1)
