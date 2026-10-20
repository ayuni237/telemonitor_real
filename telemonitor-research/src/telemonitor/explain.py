"""Interpretability — thesis ch.3 §Interpretability.

Grouped permutation importance: the features of one channel are permuted
together across samples, and the loss in ranked probability score is
measured. Permuting one of two correlated features alone (systolic and
diastolic pressure correlate at about 0.9) lets the model fall back on the
other and understates both; permuting the group measures what the channel
as a whole contributes (Gregorutti et al. 2017; Strobl et al. 2008). It is
model-agnostic, so every candidate is explained on the same scale. CatBoost
also provides exact tree SHAP values (Lundberg and Lee 2017).
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from .metrics import rps
from .models.sequence import CHANNELS, SeqInputs
from .progress import progress

# Feature groups for tabular inputs, by prefix; pulse pressure belongs to pressure.
GROUPS = {"pressure": ("sbp_", "dbp_", "pp_"), "pulse": ("hr_",), "glucose": ("glucose_",), "static": ("age", "sex_")}
SEQ_GROUPS = {"pressure": ("sbp", "dbp"), "pulse": ("hr",), "glucose": ("glucose",), "static": ()}


def _permute_tabular(X: pd.DataFrame, group: str, rng) -> pd.DataFrame:
    cols = [c for c in X.columns if c.startswith(GROUPS[group])]
    Xp = X.copy()
    if cols:
        perm = rng.permutation(len(X))
        Xp[cols] = X[cols].to_numpy()[perm]
    return Xp


def _permute_sequence(X: SeqInputs, group: str, rng) -> SeqInputs:
    perm = rng.permutation(len(X))
    values, gaps, static = X.values.copy(), X.gaps.copy(), X.static.copy()
    if group == "static":
        static = static[perm]
    else:
        idx = [CHANNELS.index(c) for c in SEQ_GROUPS[group]]
        values[:, :, idx] = X.values[perm][:, :, idx]
        gaps[:, :, idx] = X.gaps[perm][:, :, idx]
    return SeqInputs(values, gaps, X.steps, static)


def grouped_permutation_importance(model, X, y, n_repeats: int = 20, seed: int = 0) -> pd.DataFrame:
    """Mean and spread of the increase in RPS when each group is permuted."""
    rng = np.random.default_rng(seed)
    base = rps(model.predict_proba(X), y)
    permute = _permute_sequence if isinstance(X, SeqInputs) else _permute_tabular
    rows = []
    for g in progress(list(GROUPS), desc="permutation importance", unit="group"):
        deltas = [rps(model.predict_proba(permute(X, g, rng)), y) - base for _ in range(n_repeats)]
        rows.append({"group": g, "importance": float(np.mean(deltas)), "sd": float(np.std(deltas, ddof=1))})
    return pd.DataFrame(rows).sort_values("importance", ascending=False).reset_index(drop=True)


def catboost_shap(boosting, X: pd.DataFrame) -> pd.DataFrame:
    """Mean absolute tree SHAP value per feature, summed over levels (CatBoost native)."""
    from catboost import Pool
    sv = boosting.model.get_feature_importance(Pool(X.to_numpy(float)), type="ShapValues")
    sv = np.asarray(sv)
    if sv.ndim == 3:                       # (n, levels, features + 1)
        imp = np.abs(sv[:, :, :-1]).mean(axis=0).sum(axis=0)
    else:
        imp = np.abs(sv[:, :-1]).mean(axis=0)
    return pd.DataFrame({"feature": X.columns, "mean_abs_shap": imp}).sort_values("mean_abs_shap", ascending=False)
