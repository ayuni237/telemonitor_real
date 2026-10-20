"""Shared helpers for the scripts: paths and data loading.

Every script can be run from anywhere:  python scripts/<name>.py
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd  # noqa: E402

from telemonitor import eicu, quality as Q  # noqa: E402

DOUALA = ROOT / "cohortB_complete.csv"
DOUALA_CONSULTATIONS = ROOT / "data" / "patient_data_REAL_DO_NOT_MODIFY.csv"
DEMO = ROOT / "data" / "external" / "eicu-demo-2.0.1"
OUT = ROOT / "out"
OUT.mkdir(exist_ok=True)


def douala(clean: bool = True) -> pd.DataFrame:
    """Inpatient charts (scenario D); quality-controlled unless clean=False."""
    d = pd.read_csv(DOUALA, parse_dates=["date"])
    d = Q.check(d).clean if clean else d
    return d.assign(group=d["patient"])


def eicu_demo(require_heart_rate: bool = True, tolerance: float = eicu.TOLERANCE_MIN) -> pd.DataFrame:
    """eICU demo harmonised to the chart format, quality-controlled.

    Without the vitalPeriodic table (heart rate), set require_heart_rate=False
    to run on blood pressure and glucose only."""
    if require_heart_rate:
        if not eicu.verify(DEMO):
            raise SystemExit(f"eICU demo missing or checksum mismatch in {DEMO} (see BENCHMARKS.md)")
        return Q.check(eicu.load_demo(DEMO, tolerance)).clean
    read = lambda name, cols: pd.read_csv(DEMO / f"{name}.csv.gz", usecols=cols)
    no_hr = pd.DataFrame({"patientunitstayid": pd.Series(dtype="int64"),
                          "observationoffset": pd.Series(dtype=float), "heartrate": pd.Series(dtype=float)})
    d = eicu.harmonise(pd.read_csv(DEMO / "patient.csv.gz"),
                       read("diagnosis", ["patientunitstayid", "diagnosisstring"]),
                       read("pastHistory", ["patientunitstayid", "pasthistorypath"]),
                       read("vitalAperiodic", ["patientunitstayid", "observationoffset",
                                               "noninvasivesystolic", "noninvasivediastolic"]),
                       no_hr,
                       read("lab", ["patientunitstayid", "labresultoffset", "labname", "labresult"]),
                       tolerance=tolerance)
    return Q.check(d).clean


def sites_of(df: pd.DataFrame, meta: pd.DataFrame):
    """Hospital of each sample (eICU), for the outer folds."""
    return df.set_index("patient")["hospitalid"].groupby(level=0).first().reindex(meta.patient).to_numpy()
