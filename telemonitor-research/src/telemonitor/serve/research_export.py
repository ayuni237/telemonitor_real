"""Research extract: the data of the patients who consented, pseudonymised.

The app asks each patient at sign-up, separately from the terms of use, whether
their data may be used for research, and lets them change that choice in their
profile (lib/services/consent_service.dart). This extract takes only the
patients whose profile says researchConsent == true when it runs, so a
withdrawal leaves the patient out of every later extract.

Left out: name, email, phone, emergency contact, photo, messages, reading notes,
clinician comments, device tokens and the clinicians' ids. Each patient and each
reading becomes a code, a keyed hash (HMAC-SHA256) of its id. The code is the
same from one extract to the next, so extracts can be joined, and it cannot be
traced back to the account without the key. The key stays in secrets/ with the
service-account key and is never shared with the data.

Tables (CSV, UTF-8) in out/research_export/<date>/ (git-ignored):
  patients.csv  age, sex, height, weight, blood type, conditions, medications,
                checkup period, consent time, terms version
  readings.csv  measurement and record times, values, context, number of
                readings averaged, the reading corrected, quality flag
  events.csv    alerts: time, source, level, score, status, the clinician's
                verdict and action, review time, escalation, rule and model versions

    python -m telemonitor.serve.research_export --credentials secrets/service-account.json
"""
from __future__ import annotations

import argparse
import hashlib
import hmac
import logging
import secrets
from datetime import date, datetime
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
KEY_PATH = ROOT / "secrets" / "research_export.key"
OUT_DIR = ROOT / "out" / "research_export"
log = logging.getLogger("telemonitor.research_export")

PATIENT_COLS = ["patient", "age", "sex", "height", "weight", "bloodType", "conditions", "medications",
                "checkupPeriodDays", "researchConsentAt", "termsVersion"]
READING_COLS = ["patient", "reading", "measuredAt", "recordedAt", "sbp", "dbp", "hr", "hrCamera", "hrCameraQuality",
                "glucose", "context", "readingCount", "firstSbp", "firstDbp", "firstHr", "supersedes", "qualityFlag"]
EVENT_COLS = ["patient", "reading", "triggeredAt", "triggerSource", "tier", "score", "status", "verdict",
              "action", "reviewedAt", "escalated", "thresholdVersion", "modelVersion"]
LEFT_OUT = ("name, email, phone, emergency contact, photo, messages, reading notes, clinician comments, "
            "device tokens, clinician ids")


def load_key(path: Path = KEY_PATH) -> bytes:
    """The pseudonymisation key; made once, then reused so the codes stay stable."""
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(secrets.token_hex(32), encoding="utf8")
        log.info("new pseudonymisation key in %s: keep it, the same key gives the same codes", path)
    return bytes.fromhex(path.read_text(encoding="utf8").strip())


def code(key: bytes, value: str, prefix: str) -> str:
    return prefix + hmac.new(key, value.encode("utf8"), hashlib.sha256).hexdigest()[:12]


def _time(v) -> str | None:
    return v.isoformat() if isinstance(v, datetime) else None


def _items(v) -> str | None:
    """A list (or a comma-separated text typed in the console) as "a; b"."""
    if v is None:
        return None
    parts = v if isinstance(v, list) else str(v).split(",")
    return "; ".join(s for s in (str(x).strip() for x in parts) if s) or None


def consented(profile: dict) -> bool:
    return profile.get("role") == "patient" and profile.get("researchConsent") is True


def tables(patients: list[tuple[str, dict]], readings: dict[str, list[tuple[str, dict]]],
           events: dict[str, list[tuple[str, dict]]], key: bytes) -> dict[str, pd.DataFrame]:
    """The three tables, from the profiles and each patient's readings and events
    (lists of (document id, data)). Patients without consent are skipped here too."""
    rows: dict[str, list[dict]] = {"patients": [], "readings": [], "events": []}
    for uid, p in patients:
        if not consented(p):
            continue
        pid = code(key, uid, "P-")

        def rid(reading_id):
            return code(key, f"{uid}/{reading_id}", "R-") if reading_id else None

        rows["patients"].append({
            "patient": pid, "age": p.get("age"), "sex": p.get("sex"), "height": p.get("height"),
            "weight": p.get("weight"), "bloodType": p.get("bloodType"), "conditions": _items(p.get("conditions")),
            "medications": _items(p.get("medications")), "checkupPeriodDays": p.get("checkupPeriodDays"),
            "researchConsentAt": _time(p.get("researchConsentAt")), "termsVersion": p.get("termsVersion")})
        for doc_id, d in readings.get(uid, []):
            rows["readings"].append({
                "patient": pid, "reading": rid(doc_id), "measuredAt": _time(d.get("timestamp")),
                "recordedAt": _time(d.get("recordedAt")),
                **{k: d.get(k) for k in ("sbp", "dbp", "hr", "hrCamera", "hrCameraQuality", "glucose", "context",
                                         "readingCount", "firstSbp", "firstDbp", "firstHr", "qualityFlag")},
                "supersedes": rid(d.get("supersedes"))})
        for _, e in events.get(uid, []):
            rows["events"].append({
                "patient": pid, "reading": rid(e.get("readingId")), "triggeredAt": _time(e.get("tsTriggered")),
                **{k: e.get(k) for k in ("triggerSource", "tier", "score", "status", "verdict", "action",
                                         "thresholdVersion", "modelVersion")},
                "reviewedAt": _time(e.get("tsReviewed")), "escalated": "escalatedAt" in e})
    cols = {"patients": PATIENT_COLS, "readings": READING_COLS, "events": EVENT_COLS}
    return {name: pd.DataFrame(rows[name], columns=cols[name]) for name in rows}


def write(tabs: dict[str, pd.DataFrame], out: Path) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    for name, df in tabs.items():
        df.to_csv(out / f"{name}.csv", index=False, encoding="utf8")
    (out / "README.txt").write_text(
        f"TeleMonitor research extract of {date.today().isoformat()}\n"
        f"Patients who consented: {len(tabs['patients'])}; readings: {len(tabs['readings'])}; "
        f"alerts: {len(tabs['events'])}.\n"
        f"Left out: {LEFT_OUT}.\n"
        "Patients and readings are codes (keyed hash); the key is not part of the extract.\n"
        "Description of the columns: telemonitor-research/src/telemonitor/serve/research_export.py.\n",
        encoding="utf8")
    return out


class FirestoreSource:
    """Reads Firestore with the Admin SDK: the profiles of all patients, then the
    readings and alerts of those who consented only."""

    def __init__(self, credentials_path: str | Path):
        import firebase_admin
        from firebase_admin import credentials, firestore
        app = firebase_admin.initialize_app(credentials.Certificate(str(credentials_path)), name="research-export")
        self.db = firestore.client(app)

    def _docs(self, ref):
        return [(d.id, d.to_dict()) for d in ref.stream()]

    def patients(self):
        return self._docs(self.db.collection("users").where("role", "==", "patient"))

    def readings(self, uid):
        return self._docs(self.db.collection("users").document(uid).collection("readings"))

    def events(self, uid):
        return self._docs(self.db.collection("users").document(uid).collection("events"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--credentials", required=True, help="Firebase service-account JSON (never commit it)")
    ap.add_argument("--out", help=f"output folder (default: {OUT_DIR.relative_to(ROOT)}/<date>)")
    ap.add_argument("--key", default=str(KEY_PATH), help="pseudonymisation key file (made on first use)")
    a = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    key = load_key(Path(a.key))
    src = FirestoreSource(a.credentials)
    pats = [(uid, p) for uid, p in src.patients() if consented(p)]
    tabs = tables(pats, {uid: src.readings(uid) for uid, _ in pats}, {uid: src.events(uid) for uid, _ in pats}, key)
    out = write(tabs, Path(a.out) if a.out else OUT_DIR / date.today().isoformat())
    log.info("%d consenting patients, %d readings, %d alerts -> %s",
             len(tabs["patients"]), len(tabs["readings"]), len(tabs["events"]), out)


if __name__ == "__main__":
    main()
