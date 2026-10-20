import numpy as np
import pandas as pd
import pytest

from telemonitor import features as F
from telemonitor.labels import load_thresholds
from telemonitor.windows import make_samples


def patient(sbp, glucose=None, age=60, sex="F"):
    n = len(sbp)
    days = pd.to_datetime("2026-07-01") + pd.to_timedelta(np.arange(n) // 2, unit="D")
    return pd.DataFrame({"patient": 1, "date": days, "time": ["M", "S"] * (n // 2) + ["M"] * (n % 2),
                         "sbp": sbp, "dbp": [s - 50 for s in sbp], "hr": 80.0,
                         "glucose": glucose if glucose is not None else np.nan, "age": age, "sex": sex})


@pytest.fixture(scope="module")
def table():
    return load_thresholds()


def test_slope_is_per_day_and_uses_real_times(table):
    s = make_samples(patient([120.0, 126.0, 132.0, 138.0, 144.0, 150.0]), table)
    X = F.compute(s, L=48, feature_set="extended")
    last = X.iloc[-1]                                   # window: 4 readings over 36 h, +6 mmHg per 12 h
    assert last.sbp_slope == pytest.approx(12.0)
    assert last.sbp_last == 144.0 and last.pp_last == 50.0 and last.sex_male == 0.0 and last.age == 60


def test_features_never_use_the_target(table):
    s = make_samples(patient([120.0, 120.0, 120.0, 120.0, 250.0]), table)
    X = F.compute(s, L=96, feature_set="descriptors16")
    assert X.sbp_last.max() == 120.0 and X.sbp_mean.max() == 120.0   # the 250 is only ever a target


def test_unsupported_features_are_missing_not_zero(table):
    s = make_samples(patient([120.0, 121.0, 122.0]), table)
    X = F.compute(s, L=24, feature_set="extended")       # 2 readings in 24 h
    assert X.sbp_slope.isna().all() and X.sbp_sd.isna().all()
    assert X.glucose_last.isna().all() and (X.glucose_n == 0).all()


def test_slope_needs_coverage_of_half_the_window(table):
    s = make_samples(patient([120.0, 126.0, 132.0, 138.0, 144.0]), table)
    X96, X48 = F.compute(s, L=96), F.compute(s, L=48)
    assert len(s.window(1, 96)) == 3                      # 3 readings spanning 24 h
    assert np.isnan(X96.sbp_slope.iloc[1])                # 24 h < half of 96 h
    assert X48.sbp_slope.iloc[1] == pytest.approx(12.0)   # 24 h >= half of 48 h


def test_feature_sets_have_the_declared_sizes():
    assert len(F.PRIMARY) == 8 and len(F.EXTENDED) == 16 and len(F.DESCRIPTORS16) == 16
