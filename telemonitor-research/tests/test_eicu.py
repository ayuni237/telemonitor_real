from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from telemonitor import eicu
from telemonitor.labels import MGDL_PER_MMOLL, load_thresholds
from telemonitor.windows import make_samples

DEMO = Path(__file__).resolve().parents[1] / "data" / "external" / "eicu-demo-2.0.1"


def tables():
    patient = pd.DataFrame({
        "patientunitstayid": [1, 2, 3, 4], "uniquepid": ["a", "a", "b", "c"],
        "age": ["60", "> 89", "45", "16"], "gender": ["Male", "Female", "Male", "Female"], "hospitalid": 7,
        "unitadmittime24": ["06:00:00", "19:00:00", "06:00:00", "06:00:00"],
        "unitdischargeoffset": [2000, 1000, 2000, 2000]})
    diagnosis = pd.DataFrame({"patientunitstayid": [1, 3, 4],
                              "diagnosisstring": ["cardiovascular|vascular disorders|hypertension",
                                                  "pulmonary|pulmonary hypertension",
                                                  "endocrine|glucose metabolism|diabetes mellitus"]})
    past = pd.DataFrame({"patientunitstayid": [2], "pasthistorypath": [
        "notes/Progress Notes/Past History/Organ Systems/Endocrine (R)/Insulin Dependent Diabetes/insulin dependent diabetes"]})
    return patient, diagnosis, past


def test_eligibility_excludes_children_and_other_hypertensions():
    stays = eicu.eligible_stays(*tables())
    assert stays.patientunitstayid.tolist() == [1, 2]                 # 3: pulmonary HTN, 4: age 16
    assert stays.set_index("patientunitstayid").loc[1, "htn"] and stays.set_index("patientunitstayid").loc[2, "dm"]


def test_slot_grid_uses_clock_time():
    patient, *_ = tables()
    g = eicu.slot_grid(patient.iloc[[0]])                               # admitted 06:00, stays 2000 min
    assert g.offset.tolist() == [120, 840, 1560]                        # 08:00, 20:00, 08:00 next day
    assert g.time.tolist() == ["M", "S", "M"] and g.day.tolist() == [0, 0, 1]


def test_nearest_reading_within_two_hours_only():
    patient, diagnosis, past = tables()
    ap = pd.DataFrame({"patientunitstayid": 1, "observationoffset": [100, 1000],
                       "noninvasivesystolic": [150.0, 120.0], "noninvasivediastolic": [90.0, 70.0]})
    pe = pd.DataFrame({"patientunitstayid": 1, "observationoffset": [125], "heartrate": [88.0]})
    lab = pd.DataFrame({"patientunitstayid": 1, "labresultoffset": [130, 900], "labname": ["bedside glucose", "glucose"],
                        "labresult": [180.0, 300.0]})
    out = eicu.harmonise(patient, diagnosis, past, ap, pe, lab)
    s1 = out[out.patient == 1].set_index("offset")
    assert s1.loc[120, ["sbp", "dbp", "hr"]].tolist() == [150, 90, 88]
    assert s1.loc[120, "glucose"] == pytest.approx(180 / MGDL_PER_MMOLL)   # bedside only, converted
    assert 840 not in s1.index or np.isnan(s1.loc[840, "sbp"])          # 1000 is 160 min away
    assert (out.group[out.patient == 1] == "a").all()


@pytest.mark.skipif(not eicu.verify(DEMO), reason="eICU demo not downloaded or checksum mismatch")
def test_demo_harmonises_into_samples():
    d = eicu.load_demo(DEMO)
    assert d.time.isin(["M", "S"]).all() and d.group.notna().all()
    s = make_samples(d, load_thresholds())
    assert len(s) > 0
    # all stays of one patient share a group
    assert s.meta.groupby("patient").group.nunique().max() == 1
