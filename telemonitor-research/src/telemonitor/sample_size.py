"""Sample size and parameter budget — thesis ch.3 §Sampling Plan.

Port of the binary-outcome criteria of Riley et al. (BMJ 2020; Stat Med 2019),
as implemented in the reference R package pmsampsize 1.1.3 (pmsampsize_bin.R,
cstat2rsq.R), plus the design effect of clustered samples (Kish), since the
samples of one patient are not independent.
"""
from __future__ import annotations

import math

import numpy as np
from scipy.stats import norm


def cstat_to_r2cs(cstat: float, prevalence: float, n: int = 1_000_000, seed: int = 123456) -> float:
    """Cox-Snell R2 implied by a C statistic (Riley, Van Calster and Collins 2021).

    The linear predictor is N(0,1) in one class and N(mu,1) in the other with
    mu = sqrt(2) * Phi^-1(C); a logistic calibration model is fitted on a large
    simulated sample and R2_CS = 1 - exp(-LR / n)."""
    rng = np.random.default_rng(seed)
    n0 = int(round(prevalence * n))
    mu = math.sqrt(2) * norm.ppf(cstat)
    lp = np.concatenate([rng.normal(0, 1, n0), rng.normal(mu, 1, n - n0)])
    y = np.concatenate([np.zeros(n0), np.ones(n - n0)])
    beta = _logistic_fit(lp, y)
    eta = beta[0] + beta[1] * lp
    ll = np.sum(y * eta - np.logaddexp(0, eta))
    p = y.mean()
    ll0 = n * (p * math.log(p) + (1 - p) * math.log(1 - p))
    return 1 - math.exp(-2 * (ll - ll0) / n)


def _logistic_fit(x: np.ndarray, y: np.ndarray, iters: int = 50) -> np.ndarray:
    """Maximum-likelihood intercept and slope by Newton-Raphson."""
    X = np.column_stack([np.ones_like(x), x])
    b = np.zeros(2)
    for _ in range(iters):
        p = 1 / (1 + np.exp(-(X @ b)))
        step = np.linalg.solve(X.T @ (X * (p * (1 - p))[:, None]), X.T @ (y - p))
        b += step
        if np.abs(step).max() < 1e-10:
            break
    return b


def max_r2cs(n: int, prevalence: float) -> float:
    """Largest Cox-Snell R2 attainable for this outcome proportion (pmsampsize_bin.R)."""
    e = n * prevalence
    ll_null = e * math.log(e / n) + (n - e) * math.log(1 - e / n)
    return 1 - math.exp(2 * ll_null / n)


def riley_binary(r2cs: float, parameters: int, prevalence: float, shrinkage: float = 0.9) -> dict:
    """Minimum sample size under the three criteria of Riley et al. for a binary outcome."""
    if shrinkage < r2cs:
        raise ValueError("shrinkage below R2_CS: log(1 - R2/S) undefined")
    n1 = math.ceil(parameters / ((shrinkage - 1) * math.log(1 - r2cs / shrinkage)))
    mx = max_r2cs(n1, prevalence)
    s2 = r2cs / (r2cs + 0.05 * mx)
    n2 = math.ceil(parameters / ((s2 - 1) * math.log(1 - r2cs / s2)))
    n3 = math.ceil((1.96 / 0.05) ** 2 * prevalence * (1 - prevalence))
    return {"n1_shrinkage": n1, "n2_r2_difference": n2, "n3_overall_risk": n3,
            "n_required": max(n1, n2, n3), "shrinkage": max(shrinkage, s2), "max_r2cs": mx}


def max_parameters(n_eff: float, r2cs: float, prevalence: float, shrinkage: float = 0.9) -> int:
    """Largest number of candidate parameters for which n_eff meets criteria 1 and 2.

    Criterion 3 (precision of the overall risk) does not depend on the number
    of parameters and is checked separately."""
    def n_for(p):
        r = riley_binary(r2cs, p, prevalence, shrinkage)
        return max(r["n1_shrinkage"], r["n2_r2_difference"])
    p = 0
    while n_for(p + 1) <= n_eff:
        p += 1
    return p


def icc_oneway(y: np.ndarray, groups: np.ndarray) -> float:
    """One-way ANOVA intraclass correlation ICC(1) of an outcome within clusters."""
    y, groups = np.asarray(y, float), np.asarray(groups)
    labels, inv = np.unique(groups, return_inverse=True)
    k, n = len(labels), len(y)
    m = np.bincount(inv)
    means = np.bincount(inv, weights=y) / m
    grand = y.mean()
    msb = np.sum(m * (means - grand) ** 2) / (k - 1)
    msw = np.sum((y - means[inv]) ** 2) / (n - k)
    m0 = (n - np.sum(m ** 2) / n) / (k - 1)
    return float((msb - msw) / (msb + (m0 - 1) * msw))


def effective_n(groups: np.ndarray, icc: float) -> tuple[float, float]:
    """Kish design effect for unequal clusters and the effective sample size."""
    m = np.bincount(np.unique(np.asarray(groups), return_inverse=True)[1])
    m_bar = np.sum(m ** 2) / np.sum(m)
    deff = 1 + (m_bar - 1) * max(icc, 0.0)
    return float(deff), float(m.sum() / deff)
