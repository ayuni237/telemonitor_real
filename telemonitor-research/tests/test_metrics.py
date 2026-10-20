import numpy as np
import pytest

from telemonitor import metrics as M


def test_rps_is_zero_for_a_perfect_forecast_and_ordinal():
    y = np.array([0, 3])
    assert M.rps(np.eye(4)[y], y) == 0
    adjacent = M.rps(np.array([[0, 1, 0, 0.]]), np.array([0]))
    distant = M.rps(np.array([[0, 0, 0, 1.]]), np.array([0]))
    assert 0 < adjacent < distant


def test_rps_is_proper():
    rng = np.random.default_rng(0)
    true = np.array([0.1, 0.2, 0.3, 0.4])
    y = rng.choice(4, size=200_000, p=true)
    honest = M.rps(np.tile(true, (len(y), 1)), y)
    for other in ([0.25] * 4, [0.0, 0.2, 0.3, 0.5], [0.1, 0.1, 0.4, 0.4]):
        assert honest < M.rps(np.tile(other, (len(y), 1)), y)


def test_calibration_of_a_calibrated_model():
    rng = np.random.default_rng(1)
    p = rng.uniform(0.05, 0.95, 50_000)
    e = rng.random(len(p)) < p
    a, b = M.calibration_intercept_slope(p, e)
    assert a == pytest.approx(0, abs=0.05) and b == pytest.approx(1, abs=0.05)
    a2, b2 = M.calibration_intercept_slope(np.clip(p * 1.5 - 0.25, 0.01, 0.99), e)   # overconfident
    assert b2 < 0.9


def test_net_benefit_matches_its_definition():
    p = np.array([0.9, 0.8, 0.3, 0.1])
    e = np.array([1, 0, 1, 0])
    # threshold 0.5: 1 TP, 1 FP among 4 -> 1/4 - 1/4 * 1 = 0
    assert M.net_benefit(p, e, 0.5) == pytest.approx(0.0)
    assert M.net_benefit_treat_all(e, 0.2) == pytest.approx(0.5 - 0.5 * 0.25)


def test_evaluate_returns_every_measure():
    rng = np.random.default_rng(2)
    proba = rng.dirichlet(np.ones(4), 300)
    y = rng.integers(0, 4, 300)
    out = M.evaluate(proba, y)
    for key in ("rps", "brier_alert", "log_loss_alert", "auroc_alert", "cal_intercept", "cal_slope", "net_benefit_0.2"):
        assert key in out and np.isfinite(out[key])


def test_intercept_update_fixes_calibration_in_the_large():
    rng = np.random.default_rng(3)
    p = rng.uniform(0.05, 0.6, 20_000)
    e = rng.random(len(p)) < np.clip(p + 0.15, 0, 1)          # true risk higher than predicted
    a_before, _ = M.calibration_intercept_slope(p, e)
    a_after, _ = M.calibration_intercept_slope(M.update_intercept(p, e), e)
    assert a_before > 0.3 and abs(a_after) < 0.02


def test_calibration_curve_bins_and_intervals():
    rng = np.random.default_rng(4)
    p = rng.uniform(0, 1, 5000)
    e = rng.random(len(p)) < p
    cc = M.calibration_curve(p, e, bins=5)
    assert len(cc) == 5 and (cc.low <= cc.observed).all() and (cc.observed <= cc.high).all()
    assert np.allclose(cc.predicted, cc.observed, atol=0.05)


def test_calibration_curve_of_a_constant_prediction_is_one_bin():
    cc = M.calibration_curve(np.full(100, 0.3), np.r_[np.ones(30), np.zeros(70)], bins=10)
    assert len(cc) == 1 and cc.observed.iloc[0] == 0.3
