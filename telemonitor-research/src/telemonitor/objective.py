"""Selection cost of the inner folds — thesis ch.3 §Metrics, configs/cost.yaml.

Each configuration compared in an inner fold is scored on admissible terms
(metrics.evaluate). Terms live on different scales, so each is standardised
robustly across the configurations of the same comparison (median and MAD) and
oriented so that lower is better; the cost is their weighted sum. The weights
come from the configuration file, never from the data, and a sensitivity
analysis reports how often the selected configuration stays first when the
weights are drawn at random.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import yaml

DEFAULT_COST = Path(__file__).resolve().parents[2] / "configs" / "cost.yaml"


def load_cost(path: str | Path = DEFAULT_COST) -> dict:
    cfg = yaml.safe_load(Path(path).read_text(encoding="utf8"))
    w = np.array([t["weight"] for t in cfg["terms"].values()], float)
    if np.any(w < 0) or not np.isclose(w.sum(), 1.0):
        raise ValueError("weights must be non-negative and sum to 1")
    return cfg


def terms(results: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    """The raw value of each term for each configuration (rows of `results`
    are outputs of metrics.evaluate)."""
    ths = cfg["net_benefit_thresholds"]
    derived = pd.DataFrame(index=results.index)
    derived["rps"] = results["rps"]
    derived["auroc_alert"] = results["auroc_alert"]
    slope = results["cal_slope"].clip(lower=1e-6)
    derived["cal_error"] = results["cal_intercept"].abs() + np.log(slope).abs()
    derived["net_benefit"] = results[[f"net_benefit_{t:g}" for t in ths]].mean(axis=1)
    return pd.DataFrame({name: derived[t["metric"]] for name, t in cfg["terms"].items()})


def standardise(raw: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    """Robust z-scores across configurations, oriented so that lower is better."""
    z = pd.DataFrame(index=raw.index)
    for name, t in cfg["terms"].items():
        x = raw[name].astype(float)
        mad = 1.4826 * (x - x.median()).abs().median()
        scale = mad if mad > 0 else (x.std(ddof=0) or 1.0)
        sign = 1.0 if t["direction"] == "lower" else -1.0
        z[name] = sign * (x - x.median()) / scale
    return z


def selection_cost(results: pd.DataFrame, cfg: dict | None = None, weights: np.ndarray | None = None) -> pd.Series:
    cfg = cfg or load_cost()
    z = standardise(terms(results, cfg), cfg)
    w = np.array([t["weight"] for t in cfg["terms"].values()]) if weights is None else np.asarray(weights)
    return pd.Series(z.to_numpy() @ w, index=results.index, name="cost")


def rank_stability(results: pd.DataFrame, cfg: dict | None = None, seed: int = 0) -> pd.Series:
    """Share of random weightings under which each configuration has the lowest cost."""
    cfg = cfg or load_cost()
    z = standardise(terms(results, cfg), cfg).to_numpy()
    rng = np.random.default_rng(seed)
    s = cfg["sensitivity"]
    W = rng.dirichlet(np.full(z.shape[1], s["dirichlet_alpha"]), s["draws"])
    winners = np.argmin(z @ W.T, axis=0)
    share = np.bincount(winners, minlength=len(results)) / len(W)
    return pd.Series(share, index=results.index, name="share_first")
