"""eICU development cohort — eligibility, harmonisation and samples.

Reproduces the figures of thesis §Sampling Plan (development data):
  * 2520 stays of 1841 patients in 186 hospitals in the demo;
  * eligible stays (adult, hypertension or diabetes, other "hypertensions" excluded);
  * readings after resampling to 08:00 / 20:00 slots (nearest within 2 h), quality flags;
  * forecast samples, stays, patients, hospitals; prevalence of each level.
Usage: python scripts/05_eicu_cohort.py [--no-heart-rate]
"""
import argparse

import pandas as pd

import _common
from telemonitor import eicu
from telemonitor.labels import load_thresholds
from telemonitor import quality as Q
from telemonitor.windows import make_samples

ap = argparse.ArgumentParser()
ap.add_argument("--no-heart-rate", action="store_true")
a = ap.parse_args()

D = _common.DEMO
pat = pd.read_csv(D / "patient.csv.gz")
dx = pd.read_csv(D / "diagnosis.csv.gz", usecols=["patientunitstayid", "diagnosisstring"])
ph = pd.read_csv(D / "pastHistory.csv.gz", usecols=["patientunitstayid", "pasthistorypath"])
print(f"demo: {pat.patientunitstayid.nunique()} stays, {pat.uniquepid.nunique()} patients, "
      f"{pat.hospitalid.nunique()} hospitals")
st = eicu.eligible_stays(pat, dx, ph)
print(f"eligible: {len(st)} stays, {st.uniquepid.nunique()} patients, {st.hospitalid.nunique()} hospitals; "
      f"hypertension {int(st.htn.sum())}, diabetes {int(st.dm.sum())}, both {int((st.htn & st.dm).sum())}")

raw = _common.eicu_demo(require_heart_rate=not a.no_heart_rate)
print(f"harmonised readings: {len(raw)} in {raw.patient.nunique()} stays; availability "
      f"{raw[['sbp', 'dbp', 'hr', 'glucose']].notna().mean().round(3).to_dict()}")
s = make_samples(raw, load_thresholds())
m = s.meta
hosp = raw[raw.patient.isin(m.patient)].hospitalid.nunique()
print(f"samples: {len(m)} from {m.patient.nunique()} stays, {m.group.nunique()} patients, {hosp} hospitals")
for c in ("y_haemodynamic", "y_glycaemic"):
    print(c, m[c].value_counts().sort_index().to_dict(), "alert prevalence", round(float((m[c].dropna() >= 2).mean()), 3))
