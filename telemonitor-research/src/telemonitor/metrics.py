"""Admissible performance measures — thesis ch.3 §Metrics.

A measure is admissible when it has a clear focus (discrimination, calibration,
overall accuracy of the probabilities, or clinical utility) and, for overall
accuracy, when it is a proper scoring rule (Van Calster et al. 2025; Gneiting
and Raftery 2007). Accuracy and F1 are excluded: they are improper, depend on
an arbitrary threshold, and mix statistical and decision performance.

Inputs: `proba` is an (n, K) array of level probabilities (K = 4 ordered
levels); `y` the observed level (0..K-1). The alert is level >= ALERT_LEVEL.
"""
from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score

ALERT_LEVEL = 2   # high or critical


def _onehot(y: np.ndarray, k: int) -> np.ndarray:
    o = np.zeros((len(y), k))
    o[np.arange(len(y)), np.asarray(y, int)] = 1
    return o


def rps(proba: np.ndarray, y: np.ndarray) -> float:
    """Ranked probability score (Epstein 1969): strictly proper for ordered levels.
    0 is perfect; distant errors cost more than adjacent ones."""
    p = np.asarray(proba, float)
    k = p.shape[1]
    cp, co = np.cumsum(p, axis=1)[:, :-1], np.cumsum(_onehot(y, k), axis=1)[:, :-1]
    return float(np.mean(np.sum((cp - co) ** 2, axis=1) / (k - 1)))


def alert_probability(proba: np.ndarray) -> np.ndarray:
    return np.asarray(proba, float)[:, ALERT_LEVEL:].sum(axis=1)


def brier(p_alert: np.ndarray, event: np.ndarray) -> float:
    return float(np.mean((np.asarray(p_alert) - np.asarray(event)) ** 2))


def log_loss(p_alert: np.ndarray, event: np.ndarray, eps: float = 1e-12) -> float:
    p = np.clip(np.asarray(p_alert, float), eps, 1 - eps)
    e = np.asarray(event, float)
    return float(-np.mean(e * np.log(p) + (1 - e) * np.log(1 - p)))


def auroc(p_alert: np.ndarray, event: np.ndarray) -> float:
    e = np.asarray(event)
    return float(roc_auc_score(e, p_alert)) if 0 < e.mean() < 1 else float("nan")


def calibration_intercept_slope(p_alert: np.ndarray, event: np.ndarray, eps: float = 1e-6) -> tuple[float, float]:
    """Logistic recalibration of the outcome on logit(p) (Van Calster et al. 2019).

    Slope: fitted on logit(p). Intercept (calibration-in-the-large): fitted with
    logit(p) as an offset. Ideal values 1 and 0."""
    p = np.clip(np.asarray(p_alert, float), eps, 1 - eps)
    lp = np.log(p / (1 - p))
    e = np.asarray(event, float)
    a_s, b_s = _logistic(lp, e)
    a_o, _ = _logistic(lp, e, offset=True)
    return float(a_o), float(b_s)


def _logistic(lp, e, offset=False, iters=100):
    a, b = 0.0, (1.0 if offset else 0.0)
    for _ in range(iters):
        eta = a + b * lp
        p = 1 / (1 + np.exp(-eta))
        w = p * (1 - p)
        if offset:
            step = np.array([np.sum(e - p) / max(np.sum(w), 1e-12), 0.0])
        else:
            X = np.column_stack([np.ones_like(lp), lp])
            H = X.T @ (X * w[:, None]) + 1e-9 * np.eye(2)
            step = np.linalg.solve(H, X.T @ (e - p))
        a, b = a + step[0], b + step[1]
        if np.abs(step).max() < 1e-10:
            break
    return a, b


def net_benefit(p_alert: np.ndarray, event: np.ndarray, threshold: float) -> float:
    """Net benefit of alerting when p >= threshold (Vickers and Elkin 2006).

    The threshold encodes the relative harm of a false alarm and a missed
    event: odds(threshold) = harm(false alarm) / benefit(true alert)."""
    p, e = np.asarray(p_alert), np.asarray(event).astype(bool)
    alert = p >= threshold
    n = len(e)
    tp, fp = np.sum(alert & e), np.sum(alert & ~e)
    return float(tp / n - fp / n * threshold / (1 - threshold))


def net_benefit_treat_all(event: np.ndarray, threshold: float) -> float:
    prev = float(np.mean(event))
    return prev - (1 - prev) * threshold / (1 - threshold)


def evaluate(proba: np.ndarray, y: np.ndarray, thresholds=(0.1, 0.2, 0.3)) -> dict:
    """Every admissible measure for one model on one set of targets."""
    y = np.asarray(y, int)
    event = (y >= ALERT_LEVEL).astype(int)
    pa = alert_probability(proba)
    cal_a, cal_b = calibration_intercept_slope(pa, event)
    out = {"n": int(len(y)), "prevalence_alert": float(event.mean()),
           "rps": rps(proba, y), "brier_alert": brier(pa, event), "log_loss_alert": log_loss(pa, event),
           "auroc_alert": auroc(pa, event), "cal_intercept": cal_a, "cal_slope": cal_b}
    for t in thresholds:
        out[f"net_benefit_{t:g}"] = net_benefit(pa, event, t)
        out[f"net_benefit_all_{t:g}"] = net_benefit_treat_all(event, t)
    return out

def update_intercept(p_alert: np.ndarray, event: np.ndarray, eps: float = 1e-6) -> np.ndarray:
    """Recalibration-in-the-large (Janssen et al. 2008): shift the logit of
    every probability by the intercept fitted with logit(p) as an offset."""
    a, _ = calibration_intercept_slope(p_alert, event, eps)
    p = np.clip(np.asarray(p_alert, float), eps, 1 - eps)
    return 1 / (1 + np.exp(-(np.log(p / (1 - p)) + a)))


def calibration_curve(p_alert: np.ndarray, event: np.ndarray, bins: int = 5) -> pd.DataFrame:
    """Observed against predicted risk in quantile bins, with Wilson 95% intervals."""
    p, e = np.asarray(p_alert, float), np.asarray(event, float)
    edges = np.unique(np.quantile(p, np.linspace(0, 1, bins + 1)))
    if len(edges) < 2:                    # constant predictions: a single bin
        edges = np.array([p.min(), p.max() + 1e-12])
    idx = np.clip(np.searchsorted(edges, p, side="right") - 1, 0, len(edges) - 2)
    rows = []
    for b in range(len(edges) - 1):
        m = idx == b
        n, k = int(m.sum()), float(e[m].sum())
        if n == 0:
            continue
        ph, z = k / n, 1.959964
        centre = (ph + z * z / (2 * n)) / (1 + z * z / n)
        half = z * np.sqrt(ph * (1 - ph) / n + z * z / (4 * n * n)) / (1 + z * z / n)
        rows.append({"bin": b, "n": n, "predicted": float(p[m].mean()), "observed": ph,
                     "low": centre - half, "high": centre + half})
    return pd.DataFrame(rows)
