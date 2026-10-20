import numpy as np
import pandas as pd
import pytest

from telemonitor.labels import load_thresholds
from telemonitor.models import tabular as T
from telemonitor.models.levels import channel_level_proba, condition_level_proba


@pytest.fixture(scope="module")
def table():
    return load_thresholds()


def synthetic(n=600, seed=0):
    """Next systolic pressure follows the last one; level from the threshold table."""
    rng = np.random.default_rng(seed)
    t = load_thresholds()
    last = rng.uniform(85, 200, n)
    nxt = last + rng.normal(0, 6, n)
    X = pd.DataFrame({"sbp_last": last, "dbp_last": 80.0, "hr_last": 80.0, "noise": rng.normal(size=n)})
    y = t.channel_level("sbp", nxt).astype(int)
    values = pd.DataFrame({"sbp": nxt, "dbp": 80.0, "hr": 80.0})
    groups = np.arange(n) // 5
    return X, y, groups, values


def test_level_integration_sums_to_one_and_concentrates_when_sigma_is_small(table):
    mu = np.array([85.0, 120.0, 150.0, 170.0, 200.0])
    P = channel_level_proba(table, "sbp", mu, sigma=0.01)
    assert np.allclose(P.sum(axis=1), 1)
    assert P.argmax(axis=1).tolist() == table.channel_level("sbp", mu).astype(int).tolist()


def test_worst_channel_combination():
    a = np.array([[1.0, 0, 0, 0]])
    b = np.array([[0, 0, 1.0, 0]])
    assert np.allclose(condition_level_proba([a, b]), [[0, 0, 1, 0]])


def test_undo_class_weights_restores_priors():
    p = np.array([[0.25, 0.25, 0.25, 0.25]])
    w = np.array([1.0, 1.0, 2.0, 4.0])
    q = T.undo_class_weights(p, w)
    assert q[0, 3] < q[0, 2] < q[0, 0] and np.isclose(q.sum(), 1)


def test_persistence_uses_the_transition_matrix(table):
    X, y, g, v = synthetic()
    m = T.Persistence(table, "haemodynamic").fit(X, y)
    P = m.predict_proba(X)
    assert np.allclose(P.sum(axis=1), 1)
    last = table.channel_level("sbp", X.sbp_last.to_numpy()).astype(int)
    assert (P.argmax(axis=1) == last).mean() > 0.8


@pytest.mark.parametrize("make", [
    lambda t: T.OrdinalLogistic(C=10.0),
    lambda t: T.OrdinalLogistic(C=10.0, n_components=2),
    lambda t: T.Forest(params={"min_samples_leaf": 5}),
    lambda t: T.Boosting(params={"iterations": 200, "depth": 3}),
    lambda t: T.ValueForecast(t, "haemodynamic", "ridge"),
    lambda t: T.ValueForecast(t, "haemodynamic", "catboost", params={"iterations": 200, "depth": 3}),
])
def test_candidates_learn_and_return_valid_probabilities(table, make):
    X, y, g, v = synthetic()
    Xte, yte, _, _ = synthetic(seed=1)
    m = make(table).fit(X, y, g, v)
    P = m.predict_proba(Xte)
    assert P.shape == (len(Xte), 4) and np.allclose(P.sum(axis=1), 1) and (P >= 0).all()
    prior = T.Prior().fit(X, y).predict_proba(Xte)
    from telemonitor.metrics import rps
    assert rps(P, yte) < rps(prior, yte)


def test_ordinal_logistic_with_missing_values_and_weights():
    X, y, g, v = synthetic()
    X.loc[::7, "sbp_last"] = np.nan
    m = T.OrdinalLogistic(C=1.0, weights="balanced").fit(X, y)
    P = m.predict_proba(X)
    assert np.isfinite(P).all() and np.allclose(P.sum(axis=1), 1)


def test_value_forecast_ignores_a_channel_never_observed(table):
    X, y, g, v = synthetic()
    v = v.assign(hr=np.nan)
    m = T.ValueForecast(table, "haemodynamic", "ridge").fit(X, y, g, v)
    assert m.models["hr"] is None
    P = m.predict_proba(X)
    assert np.allclose(P.sum(axis=1), 1)
