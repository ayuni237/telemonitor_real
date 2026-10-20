import re
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from telemonitor.labels import MGDL_PER_MMOLL, load_thresholds

ROOT = Path(__file__).resolve().parents[1]
BIB = ROOT.parent / "memoire" / "references.bib"
COHORT = ROOT / "cohortB_complete.csv"


@pytest.fixture(scope="module")
def table():
    return load_thresholds()


def gl(g_per_l):
    """mmol/L from g/L, as the cohort file was converted."""
    return g_per_l * 1000 / (10 * MGDL_PER_MMOLL)


@pytest.mark.parametrize("value, level", [
    (180, 3), (179, 2), (160, 2), (159, 1), (140, 1), (139, 0),
    (111, 0), (91, 0), (90, 3), (71, 3),
])
def test_sbp_boundaries(table, value, level):
    assert table.channel_level("sbp", [value])[0] == level


@pytest.mark.parametrize("value, level", [
    (110, 3), (109, 2), (100, 2), (99, 1), (90, 1), (89, 0), (40, 0),
])
def test_dbp_boundaries_and_no_lower_threshold(table, value, level):
    assert table.channel_level("dbp", [value])[0] == level


@pytest.mark.parametrize("value, level", [(40, 3), (41, 0), (110, 0), (130, 0), (131, 3)])
def test_pulse_red_score_only(table, value, level):
    assert table.channel_level("pulse", [value])[0] == level


@pytest.mark.parametrize("g_per_l, level", [
    (0.53, 3),   # < 54 mg/dL, level 2 hypoglycaemia
    (0.54, 2),   # 54 mg/dL is not < 54
    (0.69, 2),   # < 70 mg/dL, level 1 hypoglycaemia
    (0.70, 0),
    (1.40, 0),   # 140 mg/dL is not > 140
    (1.41, 1),
    (1.79, 1),
    (1.80, 2),   # exactly the treatment threshold: 3 such readings in the cohort
    (3.00, 2),   # 300 mg/dL is not > 300
    (3.01, 3),
])
def test_glucose_boundaries_in_source_unit(table, g_per_l, level):
    assert table.channel_level("glucose", [gl(g_per_l)])[0] == level


def test_missing_channel_is_missing_not_stable(table):
    df = pd.DataFrame({"sbp": [150, np.nan, np.nan], "dbp": [85, np.nan, np.nan],
                       "hr": [80, np.nan, np.nan], "glucose": [np.nan, gl(1.0), np.nan]})
    out = table.label(df)
    assert np.isnan(out.s_glucose[0]) and np.isnan(out.y_glycaemic[0])
    assert out.y[0] == 1                      # haemodynamic label only
    assert np.isnan(out.y_haemodynamic[1]) and out.y[1] == 0
    assert np.isnan(out.y[2])                 # nothing measured: no label


def test_worst_channel_and_worst_condition(table):
    df = pd.DataFrame({"sbp": [145, 71], "dbp": [105, 54], "hr": [80, 102],
                       "glucose": [gl(1.5), np.nan]})
    out = table.label(df)
    assert out.y_haemodynamic.tolist() == [2, 3]   # DBP grade 2; SBP <= 90
    assert out.y_glycaemic[0] == 1 and out.y.tolist() == [2, 3]


def test_variant_caps_severe_hyperglycaemia_without_touching_base(table):
    capped = table.variant("cap_severe_hyperglycaemia")
    assert capped.channel_level("glucose", [gl(3.5)])[0] == 2
    assert table.channel_level("glucose", [gl(3.5)])[0] == 3
    with pytest.raises(KeyError):
        table.variant("nope")


def test_invalid_table_is_rejected(tmp_path):
    bad = (ROOT / "configs" / "thresholds.yaml").read_text(encoding="utf8")
    bad = bad.replace("op: ge, value: 180, source: mancia2023", "op: geq, value: 180, source: mancia2023")
    p = tmp_path / "bad.yaml"
    p.write_text(bad, encoding="utf8")
    with pytest.raises(ValueError, match="unknown op"):
        load_thresholds(p)


@pytest.mark.skipif(not BIB.exists(), reason="thesis bibliography not found")
def test_every_source_is_in_the_thesis_bibliography(table):
    keys = set(re.findall(r"^@\w+\{([^,]+),", BIB.read_text(encoding="utf8"), flags=re.M))
    sources = {r.source for rs in table.rules.values() for r in rs}
    assert sources <= keys, f"missing from references.bib: {sorted(sources - keys)}"


@pytest.mark.skipif(not COHORT.exists(), reason="cohort file not found")
def test_cohort_labels_are_complete_where_blood_pressure_is_measured(table):
    d = pd.read_csv(COHORT)
    out = table.label(d)
    assert set(out.y.dropna().unique()) <= {0, 1, 2, 3}
    assert out.y[d.sbp.notna()].notna().all()
