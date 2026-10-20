"""Validation design — thesis ch.3 §Training protocol.

* outer folds grouped by hospital (internal-external validation), stratified on
  the presence of an alert so that no test fold is empty of events;
* inner folds grouped by patient, on the outer training data only;
* repetitions with different fold assignments;
* corrected resampled t test (Nadeau and Bengio 2003) to compare two models
  evaluated on the same folds;
* patient-level (cluster) bootstrap for confidence intervals on external data.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterator

import numpy as np
from scipy import stats
from sklearn.model_selection import StratifiedGroupKFold

from .progress import progress


@dataclass(frozen=True)
class Split:
    repeat: int
    fold: int
    train: np.ndarray
    test: np.ndarray


def outer_splits(y_event: np.ndarray, sites: np.ndarray, n_splits: int = 5,
                 repeats: int = 1, seed: int = 0) -> Iterator[Split]:
    """Outer folds: grouped by site, stratified on the presence of an event."""
    y = np.asarray(y_event).astype(int)
    for r in range(repeats):
        cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=seed + r)
        for k, (tr, te) in enumerate(cv.split(np.zeros(len(y)), y, sites)):
            yield Split(r, k, tr, te)


def inner_splits(y_event: np.ndarray, patients: np.ndarray, n_splits: int = 4, seed: int = 0) -> list[tuple]:
    """Inner folds on an outer training set: grouped by patient."""
    y = np.asarray(y_event).astype(int)
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=seed)
    return list(cv.split(np.zeros(len(y)), y, patients))


def corrected_ttest(diff: np.ndarray, n_train: float, n_test: float) -> tuple[float, float]:
    """Corrected resampled t test on per-fold score differences between two models.

    The variance is inflated by n_test / n_train to account for overlapping
    training sets (Nadeau and Bengio 2003). Returns (t, two-sided p)."""
    d = np.asarray(diff, float)
    k = len(d)
    var = d.var(ddof=1)
    if var == 0:
        return (np.inf if d.mean() else 0.0), (0.0 if d.mean() else 1.0)
    t = d.mean() / np.sqrt((1 / k + n_test / n_train) * var)
    return float(t), float(2 * stats.t.sf(abs(t), df=k - 1))


def cluster_bootstrap(metric: Callable[[np.ndarray], float], clusters: np.ndarray,
                      n_boot: int = 2000, seed: int = 0, alpha: float = 0.05) -> tuple[float, float, float]:
    """Point estimate and percentile interval, resampling whole clusters (patients).

    `metric` receives an array of row indices and returns a number."""
    clusters = np.asarray(clusters)
    ids, inv = np.unique(clusters, return_inverse=True)
    rows_of = [np.flatnonzero(inv == i) for i in range(len(ids))]
    rng = np.random.default_rng(seed)
    point = metric(np.arange(len(clusters)))
    boots = []
    for _ in progress(range(n_boot), desc="   patient bootstrap", leave=False, unit="resample"):
        pick = rng.integers(0, len(ids), len(ids))
        value = metric(np.concatenate([rows_of[i] for i in pick]))
        if np.isfinite(value):
            boots.append(value)
    lo, hi = np.percentile(boots, [100 * alpha / 2, 100 * (1 - alpha / 2)])
    return float(point), float(lo), float(hi)
