from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from telemonitor import quality as Q
from telemonitor.labels import load_thresholds
from telemonitor.windows import make_samples

COHORT = Path(__file__).resolve().parents[1] / "cohortB_complete.csv"


def patient(pid, sbp, glucose=None, start="2026-07-01"):
    n = len(sbp)
    days = pd.to_datetime(start) + pd.to_timedelta(np.arange(n) // 2, unit="D")
    return pd.DataFrame({"patient": pid, "date": days, "time": ["M", "S"] * (n // 2) + ["M"] * (n % 2),
                         "sbp": sbp, "dbp": 80.0, "hr": 80.0,
                         "glucose": glucose if glucose is not None else np.nan})


@pytest.fixture(scope="module")
def table():
    return load_thresholds()


def test_target_is_never_in_the_window(table):
    s = make_samples(patient(1, [130.0] * 10), table, eps=12)
    for k in range(len(s)):
        win = s.window(k, 96)
        assert s.data.t.iat[s.meta.target.iat[k]] > s.data.t.iloc[win].max() + 12 - 1e-9
        assert s.meta.anchor.iat[k] == win[-1]


def test_lead_time_follows_the_embargo(table):
    df = patient(1, [130.0] * 10)
    for eps, lead in ((0, 12), (12, 24), (36, 48)):
        assert set(make_samples(df, table, eps).meta.lead_h) == {lead}


def test_anchor_set_does_not_depend_on_window_length(table):
    s = make_samples(patient(1, [130.0] * 10), table)
    # first anchor needs two readings within 24 h; last reading has no target
    assert len(s) == 10 - 1 - 1
    assert [len(s.window(0, L)) for L in (24, 48, 96)] == [2, 2, 2]
    assert [len(s.window(len(s) - 1, L)) for L in (24, 48, 96)] == [2, 4, 8]


def test_windows_stay_within_one_patient(table):
    df = pd.concat([patient(1, [130.0] * 6), patient(2, [170.0] * 6)])
    s = make_samples(df, table)
    for k in range(len(s)):
        assert (s.data.patient.iloc[s.window(k, 1e6)] == s.meta.patient.iat[k]).all()


def test_glycaemic_label_only_where_glucose_is_measured(table):
    g = [6.0, np.nan, 6.0, 12.0, np.nan, 6.0]
    s = make_samples(patient(1, [130.0] * 6, glucose=g), table)
    tg = s.meta.target.to_numpy()
    assert s.meta.y_glycaemic.isna().tolist() == list(np.isnan(np.array(g)[tg]))
    assert s.meta.y_both.isna().equals(s.meta.y_glycaemic.isna())


@pytest.mark.skipif(not COHORT.exists(), reason="cohort file not found")
def test_cohort_sample_counts(table):
    d = Q.check(pd.read_csv(COHORT, parse_dates=["date"])).clean
    s = make_samples(d, table)
    assert len(s) == 283 and s.meta.patient.nunique() == 32
    assert set(s.meta.lead_h) == {12.0}
