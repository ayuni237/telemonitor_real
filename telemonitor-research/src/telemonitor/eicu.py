"""eICU development data harmonised to the format of the Douala charts.

Thesis ch.3 §Sampling Plan: every adult stay with hypertension or diabetes in the
diagnoses or the past history is eligible; each stay is resampled to two slots a
day (08:00 and 20:00), each taking the non-invasive cuff pressure, the monitor
pulse and the bedside capillary glucose nearest to the slot within two hours.
The output has the columns of the cohort file, so quality controls, labels and
windows apply unchanged:
    patient  - unit stay (the sequence unit: windows never cross stays)
    group    - unique patient (the split unit: all stays of a patient together)
    date, time (M/S), sbp, dbp, hr, glucose (mmol/L)
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd

from .labels import MGDL_PER_MMOLL
from .progress import progress

SLOTS = {"M": 8 * 60, "S": 20 * 60}   # minutes after midnight
TOLERANCE_MIN = 120
BASE_DATE = pd.Timestamp("2000-01-01")  # eICU dates are not released; day index only

# Hypertension and diabetes in free-text paths; other "hypertensions" are not the condition.
_HTN = re.compile(r"hypertension", re.I)
_NOT_HTN = re.compile(r"pulmonary|intracranial|portal|ocular|intra-abdominal|gestational|pregnancy", re.I)
_DM = re.compile(r"diabet", re.I)
_NOT_DM = re.compile(r"insipidus|gestational", re.I)


def _matches(text: pd.Series, yes: re.Pattern, no: re.Pattern) -> pd.Series:
    t = text.fillna("")
    return t.str.contains(yes) & ~t.str.contains(no)


def eligible_stays(patient: pd.DataFrame, diagnosis: pd.DataFrame, past: pd.DataFrame) -> pd.DataFrame:
    """Adult stays with hypertension and/or diabetes; flags per condition."""
    age = pd.to_numeric(patient["age"].replace("> 89", "90"), errors="coerce")
    adult = patient.assign(age=age, sex=patient["gender"].map({"Male": "M", "Female": "F"})).loc[
        age >= 18, ["patientunitstayid", "uniquepid", "hospitalid", "age", "sex", "unitadmittime24", "unitdischargeoffset"]]
    rows = pd.concat([
        diagnosis[["patientunitstayid"]].assign(text=diagnosis["diagnosisstring"]),
        past[["patientunitstayid"]].assign(text=past["pasthistorypath"]),
    ])
    flags = rows.assign(htn=_matches(rows.text, _HTN, _NOT_HTN), dm=_matches(rows.text, _DM, _NOT_DM))
    flags = flags.groupby("patientunitstayid")[["htn", "dm"]].any().reset_index()
    out = adult.merge(flags, on="patientunitstayid", how="inner")
    return out[out.htn | out.dm].reset_index(drop=True)


def slot_grid(stays: pd.DataFrame) -> pd.DataFrame:
    """Offsets (minutes from unit admission) of every 08:00 / 20:00 slot within each stay."""
    t0 = pd.to_timedelta(stays["unitadmittime24"]).dt.total_seconds().to_numpy() / 60
    rows = []
    for sid, m0, end in progress(zip(stays.patientunitstayid, t0, stays.unitdischargeoffset), total=len(stays),
                                 desc="eICU slots", unit="stay"):
        for day in range(int((m0 + end) // 1440) + 1):
            for slot, clock in SLOTS.items():
                off = day * 1440 + clock - m0
                if 0 <= off <= end:
                    rows.append((sid, day, slot, off))
    return pd.DataFrame(rows, columns=["patientunitstayid", "day", "time", "offset"])


def _nearest(grid: pd.DataFrame, obs: pd.DataFrame, offset_col: str, value_cols: list[str],
             tolerance: float = TOLERANCE_MIN) -> pd.DataFrame:
    """For each slot, the observation nearest in time within the tolerance."""
    obs = obs.dropna(subset=value_cols, how="all")
    obs = obs.assign(**{offset_col: obs[offset_col].astype(float),
                        "patientunitstayid": obs["patientunitstayid"].astype("int64")}).sort_values(offset_col)
    grid = grid.assign(patientunitstayid=grid["patientunitstayid"].astype("int64"))
    g = grid.assign(offset=grid["offset"].astype(float)).sort_values("offset")
    m = pd.merge_asof(g, obs[["patientunitstayid", offset_col] + value_cols],
                      left_on="offset", right_on=offset_col, by="patientunitstayid",
                      direction="nearest", tolerance=tolerance)
    return m.drop(columns=offset_col)


def harmonise(patient, diagnosis, past, aperiodic, periodic, lab, tolerance: float = TOLERANCE_MIN) -> pd.DataFrame:
    """Douala-format readings for the eligible eICU stays; `tolerance` in minutes around each slot."""
    stays = eligible_stays(patient, diagnosis, past)
    grid = slot_grid(stays)
    bp = aperiodic.rename(columns={"noninvasivesystolic": "sbp", "noninvasivediastolic": "dbp"})
    # a cuff reading needs both values: a lone systolic or diastolic is not a reading
    bp = bp.dropna(subset=["sbp", "dbp"])
    hr = periodic.rename(columns={"heartrate": "hr"})
    glu = lab[lab["labname"].str.lower() == "bedside glucose"].rename(columns={"labresult": "glucose_mgdl"})
    out = _nearest(grid, bp, "observationoffset", ["sbp", "dbp"], tolerance)
    out = _nearest(out, hr, "observationoffset", ["hr"], tolerance)
    out = _nearest(out, glu, "labresultoffset", ["glucose_mgdl"], tolerance)
    out["glucose"] = out.pop("glucose_mgdl") / MGDL_PER_MMOLL
    out = out.merge(stays[["patientunitstayid", "uniquepid", "hospitalid", "age", "sex", "htn", "dm"]], on="patientunitstayid")
    out = out.rename(columns={"patientunitstayid": "patient", "uniquepid": "group"})
    out["date"] = BASE_DATE + pd.to_timedelta(out["day"], unit="D")
    keep = out[["sbp", "dbp", "hr", "glucose"]].notna().any(axis=1)
    cols = ["patient", "group", "hospitalid", "age", "sex", "htn", "dm", "date", "time", "offset", "sbp", "dbp", "hr", "glucose"]
    return out.loc[keep, cols].sort_values(["patient", "offset"]).reset_index(drop=True)


REQUIRED = ("patient", "diagnosis", "pastHistory", "vitalAperiodic", "vitalPeriodic", "lab")


def verify(folder: str | Path) -> bool:
    """True when every required table matches the published SHA-256 checksum."""
    import hashlib
    f = Path(folder)
    sums = f / "SHA256SUMS.txt"
    if not sums.exists():
        return False
    expected = dict(line.split()[::-1] for line in sums.read_text().splitlines() if line.strip())
    for name in REQUIRED:
        path = f / f"{name}.csv.gz"
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != expected.get(path.name):
            return False
    return True


def load_demo(folder: str | Path, tolerance: float = TOLERANCE_MIN) -> pd.DataFrame:
    """Read the eICU tables from a folder of .csv.gz files and harmonise them."""
    f = Path(folder)
    read = lambda name, cols=None: pd.read_csv(f / f"{name}.csv.gz", usecols=cols)
    return harmonise(
        read("patient"),
        read("diagnosis", ["patientunitstayid", "diagnosisstring"]),
        read("pastHistory", ["patientunitstayid", "pasthistorypath"]),
        read("vitalAperiodic", ["patientunitstayid", "observationoffset", "noninvasivesystolic", "noninvasivediastolic"]),
        read("vitalPeriodic", ["patientunitstayid", "observationoffset", "heartrate"]),
        read("lab", ["patientunitstayid", "labresultoffset", "labname", "labresult"]),
        tolerance=tolerance,
    )
