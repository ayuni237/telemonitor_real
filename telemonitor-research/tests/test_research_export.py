from datetime import datetime, timezone

from telemonitor.serve import research_export as X

KEY = bytes(range(32))
T = datetime(2026, 11, 10, 7, 30, tzinfo=timezone.utc)

PROFILES = [
    ("pat1", {"role": "patient", "name": "Aline Nkeng", "email": "a.nkeng@example.org", "phone": "+237 6 99 00 00 00",
              "emergencyContact": "Paul, 6 77 00 00 00", "age": 58, "sex": "Female", "conditions": ["Hypertension"],
              "medications": "Amlodipine, Metformin", "fcmTokens": ["tok"], "assignedClinicianId": "doc1",
              "researchConsent": True, "researchConsentAt": T, "termsVersion": "2026-11-14"}),
    ("pat2", {"role": "patient", "name": "No Consent", "researchConsent": False}),
    ("pat3", {"role": "patient", "name": "Before Terms"}),   # account made before the consent existed
    ("doc1", {"role": "clinician", "name": "Dr X", "researchConsent": True}),
]
READINGS = {"pat1": [("r1", {"timestamp": T, "recordedAt": T, "sbp": 150, "dbp": 95, "hr": 70, "hrCamera": 72,
                             "hrCameraQuality": 0.83, "context": "Morning",
                             "readingCount": 2, "notes": "felt dizzy at my sister's house", "qualityFlag": None}),
                     ("r2", {"timestamp": T, "recordedAt": T, "sbp": 145, "dbp": 92, "context": "Morning",
                             "readingCount": 1, "supersedes": "r1", "notes": ""})],
            "pat2": [("r9", {"timestamp": T, "sbp": 200, "dbp": 120})]}
EVENTS = {"pat1": [("rule_r2", {"readingId": "r2", "tsTriggered": T, "triggerSource": "rule", "tier": "yellow",
                                "status": "closed", "verdict": "confirmed", "action": "advice", "tsReviewed": T,
                                "comment": "Spoke with Aline by phone", "reviewedBy": "doc1", "clinicianId": "doc1",
                                "escalatedAt": T, "escalatedTo": "doc2"})]}


def tabs():
    return X.tables(PROFILES, READINGS, EVENTS, KEY)


def test_only_patients_who_consented():
    t = tabs()
    assert len(t["patients"]) == 1
    assert len(t["readings"]) == 2 and len(t["events"]) == 1


def test_nothing_that_identifies_the_patient():
    t = tabs()
    text = "\n".join(df.to_csv(index=False) for df in t.values())
    for s in ("Aline", "Nkeng", "example.org", "+237", "Paul", "dizzy", "Spoke", "tok", "doc1", "doc2", "pat1", "r1,"):
        assert s not in text, s
    assert list(t["patients"].columns) == X.PATIENT_COLS


def test_codes_are_stable_keyed_and_link_the_tables():
    t = tabs()
    p = t["patients"].patient.iloc[0]
    assert p.startswith("P-") and set(t["readings"].patient) == {p} and set(t["events"].patient) == {p}
    assert tabs()["patients"].patient.iloc[0] == p                                   # same key, same code
    assert X.tables(PROFILES, READINGS, EVENTS, bytes(32))["patients"].patient.iloc[0] != p   # other key
    r = t["readings"].set_index("reading")
    corrected = r[r.supersedes.notna()]
    assert corrected.supersedes.iloc[0] in r.index                                  # the correction names r1
    assert t["events"].reading.iloc[0] == corrected.index[0]                        # the alert names r2


def test_values_kept():
    t = tabs()
    pat = t["patients"].iloc[0]
    assert (pat.age, pat.sex, pat.medications, pat.conditions) == (58, "Female", "Amlodipine; Metformin", "Hypertension")
    ev = t["events"].iloc[0]
    assert (ev.tier, ev.verdict, ev.action, bool(ev.escalated)) == ("yellow", "confirmed", "advice", True)
    assert t["readings"].measuredAt.iloc[0] == T.isoformat()
    # monitor and camera pulse of the same reading: a pair for the Bland-Altman comparison
    r1 = t["readings"].iloc[0]
    assert (r1.hr, r1.hrCamera, r1.hrCameraQuality) == (70, 72, 0.83)


def test_empty_extract_keeps_the_columns(tmp_path):
    t = X.tables([PROFILES[1]], READINGS, EVENTS, KEY)
    out = X.write(t, tmp_path / "x")
    assert (out / "readings.csv").read_text(encoding="utf8").startswith("patient,reading,measuredAt")
    assert "Patients who consented: 0" in (out / "README.txt").read_text(encoding="utf8")


def test_key_is_made_once_and_reused(tmp_path):
    k = tmp_path / "s" / "research_export.key"
    first = X.load_key(k)
    assert len(first) == 32 and X.load_key(k) == first
