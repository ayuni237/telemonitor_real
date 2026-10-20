from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from telemonitor import quality as Q
from telemonitor.labels import MGDL_PER_MMOLL, load_thresholds

COHORT = Path(__file__).resolve().parents[1] / "cohortB_complete.csv"


def frame(rows):
    cols = ["patient", "date", "time", "sbp", "dbp", "hr", "glucose"]
    return pd.DataFrame(rows, columns=cols)


def test_impossible_values_leave_the_clean_frame_but_stay_flagged():
    df = frame([[1, "2026-07-01", "M", 92, 24, 96, 11.1],     # DBP 24 out of range
                [1, "2026-07-01", "S", 102, 100, 88, 5.0],    # pulse pressure 2
                [1, "2026-07-02", "M", 130, 80, 300, 400.0]]) # HR impossible; glucose 400 is mg/dL
    r = Q.check(df)
    assert r.flags.out_of_range_dbp.tolist() == [True, False, False]
    assert np.isnan(r.clean.dbp[0]) and r.clean.sbp[0] == 92        # only the impossible value goes
    assert r.flags.incoherent_bp[1] and np.isnan(r.clean.sbp[1]) and np.isnan(r.clean.dbp[1])
    assert np.isnan(r.clean.hr[2]) and np.isnan(r.clean.glucose[2])
    assert r.flags.unit_suspect_glucose[2]


def test_glucose_entered_in_g_per_l_is_unit_suspect():
    r = Q.check(frame([[1, "2026-07-01", "M", 130, 80, 80, 0.95]]))
    assert r.flags.unit_suspect_glucose[0] and np.isnan(r.clean.glucose[0])


def test_duplicates_keep_the_first_reading():
    r = Q.check(frame([[1, "2026-07-01", "M", 130, 80, 80, 5.0],
                       [1, "2026-07-01", "M", 131, 81, 80, 5.0]]))
    assert r.flags.duplicate.tolist() == [False, True] and len(r.clean) == 1


def test_carried_forward_runs():
    rows = [[1, f"2026-07-0{i}", "M", 130, 80 + i, 80, np.nan] for i in range(1, 5)]
    r = Q.check(frame(rows))
    assert r.flags.carried_forward_sbp.all() and not r.flags.carried_forward_dbp.any()


def test_extreme_value_is_flagged_kept_and_marked_contradicted_when_next_is_normal():
    sbp = [130, 132, 128, 131, 129, 200, 130, 131]
    rows = [[1, f"2026-07-{i + 1:02d}", "M", s, 80, 80, np.nan] for i, s in enumerate(sbp)]
    r = Q.check(frame(rows))
    assert r.flags.extreme_sbp.tolist() == [False] * 5 + [True] + [False] * 2
    assert r.flags.contradicted_sbp[5]
    assert r.clean.sbp[5] == 200                                    # possible but extreme: kept


def test_terminal_digits_distinguish_electronic_from_manual():
    rng = np.random.default_rng(0)
    electronic = Q.terminal_digits(rng.integers(100, 180, 2000))
    manual = Q.terminal_digits(2 * rng.integers(50, 90, 2000))      # 2 mmHg graduation
    assert abs(electronic["odd"] - 0.5) < 0.05 and electronic["chi2_p_uniform"] > 0.01
    assert manual["odd"] == 0 and manual["chi2_p_uniform"] < 1e-6


def test_label_uncertainty_near_and_far_from_boundaries():
    t = load_thresholds()
    near = pd.DataFrame({"sbp": [178.0], "dbp": [70.0], "glucose": [180 / MGDL_PER_MMOLL]})
    u = Q.label_uncertainty(t, near)
    assert u["sbp"] == 1.0 and u["dbp"] == 0.0 and u["glucose"] == 1.0


@pytest.mark.skipif(not COHORT.exists(), reason="cohort file not found")
def test_cohort_quality_controls():
    d = pd.read_csv(COHORT)
    r = Q.check(d)
    s = r.summary()
    assert s["out_of_range_dbp"] == 1 and s["incoherent_bp"] == 1 and s["duplicate"] == 0
    assert Q.terminal_digits(d.sbp)["odd"] > 0.4                    # not a 2 mmHg manual scale
