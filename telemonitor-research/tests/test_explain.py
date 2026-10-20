import numpy as np
import pandas as pd

from telemonitor import explain as E
from telemonitor.models import tabular as T
from test_models_tabular import synthetic


def test_grouped_importance_finds_the_informative_channel():
    X, y, g, v = synthetic()
    X["glucose_last"] = np.random.default_rng(5).normal(size=len(X))      # pure noise
    m = T.OrdinalLogistic(C=10.0).fit(X, y)
    imp = E.grouped_permutation_importance(m, X, y, n_repeats=5)
    assert imp.group.iloc[0] == "pressure" and imp.importance.iloc[0] > 0.01
    assert abs(imp.set_index("group").loc["glucose", "importance"]) < 0.005


def test_correlated_twin_does_not_hide_the_group():
    X, y, g, v = synthetic()
    X["dbp_last"] = X["sbp_last"] - 50 + np.random.default_rng(6).normal(0, 1, len(X))   # near copy
    m = T.Forest(params={"min_samples_leaf": 5}).fit(X, y)
    imp = E.grouped_permutation_importance(m, X, y, n_repeats=5).set_index("group")
    assert imp.loc["pressure", "importance"] > 0.02


def test_catboost_shap_ranks_the_signal_first():
    X, y, g, v = synthetic()
    m = T.Boosting(params={"iterations": 150, "depth": 3}).fit(X, y)
    shap = E.catboost_shap(m, X)
    assert shap.feature.iloc[0] == "sbp_last"
