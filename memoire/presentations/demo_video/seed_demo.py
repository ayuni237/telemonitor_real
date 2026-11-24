"""Demo accounts for the defence video: one clinician and three patients, with two
weeks of home readings ending now, written to Firestore with the service account.

    docker compose run --rm research python /memoire/presentations/demo_video/seed_demo.py \
        --credentials /work/secrets/service-account.json

Run it again right before recording: the history is rebuilt to end at that moment,
and whatever was entered on the demo accounts meanwhile (readings, alerts, messages)
is cleared. Accounts, passwords and registered phones are kept. Close the app on the
phone first: an open app runs the model on the half-deleted history while the old
readings are removed, and raises a model alert for a reading that is then gone.

    --plan     print the readings and write nothing (no key needed)
    --delete   remove the demo accounts and all their data (after the defence)

Everything is invented. All four accounts decline research consent, so the research
extract (research_export.py) never contains them. Passwords are written to
secrets/demo_accounts.txt, next to the key (git-ignored).

The history is written as the phones would have written it: each reading recorded a
couple of minutes after it was measured and already checked by the worker, rule
events for the readings at yellow, closed with a verdict when old. Esther's history
stays below the model's yellow cut-point (risk service, CatBoost), so neither her
phone nor the worker raises an alert before the recording; her red reading is the
one entered on camera.
"""
from __future__ import annotations

import argparse
import random
import secrets
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

DOUALA = timezone(timedelta(hours=1))        # West Africa Time, no daylight saving
TERMS_VERSION = "2026-11-14"                  # ConsentService.termsVersion in the app
HOME_VERSION = "home-2026-10-22"              # HomeProtocol.version in the app
CODE = "DLA7K2"                               # clinician enrolment code
SECRETS = Path("/work/secrets")


@dataclass
class Person:
    key: str
    email: str
    name: str
    role: str
    profile: dict = field(default_factory=dict)


CLINICIAN = Person("clinician", "paul.ndoumbe@example.com", "Dr. Paul Ndoumbe", "clinician")
ESTHER = Person("esther", "esther.mbella@example.com", "Esther Mbella", "patient", {
    "age": 56, "sex": "Female", "height": "162 cm", "weight": "78 kg",
    "conditions": ["Hypertension", "Type 2 diabetes"],
    "medications": ["Amlodipine 10 mg, morning", "Metformin 500 mg, twice daily"]})
JOSEPH = Person("joseph", "joseph.tchoua@example.com", "Joseph Tchoua", "patient", {
    "age": 63, "sex": "Male", "height": "171 cm", "weight": "84 kg",
    "conditions": ["Hypertension"], "medications": ["Losartan 50 mg, morning"]})
BRIGITTE = Person("brigitte", "brigitte.ngassa@example.com", "Brigitte Ngassa", "patient", {
    "age": 48, "sex": "Female", "height": "158 cm", "weight": "71 kg",
    "conditions": ["Type 2 diabetes"],
    "medications": ["Metformin 850 mg, twice daily", "Gliclazide 30 mg, morning"]})
PATIENTS = [ESTHER, JOSEPH, BRIGITTE]


# ------------------------------------------------------------------ plan
def slot(day: datetime, hour: float, rnd: random.Random) -> datetime:
    """A measurement time near `hour` (local), as a UTC datetime."""
    t = day + timedelta(hours=hour, minutes=rnd.randint(-20, 25))
    return t.astimezone(timezone.utc)


def bp_pair(sbp: float, dbp: float, hr: float, rnd: random.Random) -> dict:
    """Protocol pair: the first reading is kept for audit, the second retained."""
    s, d, h = round(sbp), round(dbp), round(hr)
    return {"sbp": s, "dbp": d, "hr": h, "readingCount": 2,
            "firstSbp": s + rnd.randint(2, 6), "firstDbp": d + rnd.randint(0, 3), "firstHr": h + rnd.randint(0, 4)}


def plan(now: datetime) -> dict[str, list[dict]]:
    """Readings of each patient, oldest first; `ts` is the measurement time (UTC)."""
    rnd = random.Random(20261122)
    today = now.astimezone(DOUALA).replace(hour=0, minute=0, second=0, microsecond=0)
    out: dict[str, list[dict]] = {p.key: [] for p in PATIENTS}

    def add(who: str, ts: datetime, **values) -> None:
        if ts < now - timedelta(minutes=30):          # nothing in the future, nor in the last half hour
            out[who].append({"ts": ts, "context": "", "notes": "", "readingCount": 1, **values})

    for back in range(13, -1, -1):                    # 14 days, today included
        day = today - timedelta(days=back)
        k = 13 - back                                 # 0 .. 13
        # Esther: morning and evening pairs; glucose every two or three days (strips are
        # dear), fasting or after a meal, the last one two days back; systolic slowly rising
        # (about +6 mmHg over the fortnight), all below the home targets; two missed sessions.
        # With these values the model stays below its yellow cut-point (0.1) until the red
        # reading; with glucose in the last 24 h or a slower pulse it sits at 0.12-0.15.
        if k not in (4,):
            sbp = 113 + 0.55 * k + rnd.uniform(-2.5, 2.5)
            dbp = 71 + 0.3 * k + rnd.uniform(-2, 2)
            v = bp_pair(sbp, dbp, rnd.uniform(77, 85), rnd)
            if k % 3 == 2:
                v.update(glucose=round(rnd.uniform(5.6, 6.5), 1), context="Fasting")
            add("esther", slot(day, 7.0, rnd), **v)
        if k not in (9,):
            sbp = 110 + 0.55 * k + rnd.uniform(-2.5, 2.5)
            dbp = 69 + 0.3 * k + rnd.uniform(-2, 2)
            v = bp_pair(sbp, dbp, rnd.uniform(78, 86), rnd)
            if k % 4 == 2:
                v.update(glucose=round(rnd.uniform(7.6, 9.0), 1), context="After meal")
            add("esther", slot(day, 19.75, rnd), **v)

        # Joseph: evening pressure only, around 129/80; one yellow reading 12 days ago (reviewed),
        # one yesterday evening (still open in the queue).
        if back == 12:
            add("joseph", slot(day, 19.5, rnd), **bp_pair(139, 86, 74, rnd))
        elif back == 1:
            add("joseph", slot(day, 19.5, rnd), **bp_pair(148, 91, 77, rnd))
        elif k % 5 != 3:
            add("joseph", slot(day, 19.5, rnd),
                **bp_pair(129 + rnd.uniform(-4, 4), 80 + rnd.uniform(-3, 3), rnd.uniform(66, 76), rnd))

        # Brigitte: fasting glucose and pressure each morning, after-meal glucose some evenings;
        # nothing for the last five days (the non-transmission sweep raises her alert).
        if back >= 5:
            add("brigitte", slot(day, 6.75, rnd),
                **bp_pair(124 + rnd.uniform(-4, 4), 78 + rnd.uniform(-3, 3), rnd.uniform(72, 82), rnd),
                glucose=round(rnd.uniform(6.0, 6.9), 1), context="Fasting")
            if k % 2 == 0:
                add("brigitte", slot(day, 14.0, rnd), glucose=round(rnd.uniform(8.0, 9.6), 1), context="After meal")
    return out


# ------------------------------------------------------------------ Firestore
def reading_doc(r: dict, rnd: random.Random) -> dict:
    """Fields of the app's Reading.toFirestore, plus the worker's check (already done)."""
    d = {k: v for k, v in r.items() if k != "ts"}
    d.update(timestamp=r["ts"], recordedAt=r["ts"] + timedelta(minutes=rnd.randint(1, 4)), entryMode="manual",
             qualityCheckedAt=r["ts"] + timedelta(minutes=6), qualityFlag="ok")
    for k in ("sbp", "dbp", "hr", "glucose"):
        d.setdefault(k, None)
    return d


def trigger(r: dict) -> dict:
    return {"sbp": r.get("sbp"), "dbp": r.get("dbp"), "hr": r.get("hr"), "glucose": r.get("glucose"),
            "context": r.get("context", ""), "measuredAt": r["ts"]}


def is_yellow_bp(r: dict) -> bool:
    return r.get("sbp") is not None and (r["sbp"] >= 135 or r["dbp"] >= 85)


def ensure_account(auth, p: Person, passwords: dict) -> str:
    try:
        return auth.get_user_by_email(p.email).uid
    except auth.UserNotFoundError:
        pw = f"Douala-{secrets.randbelow(900000) + 100000}"
        passwords[p.email] = pw
        return auth.create_user(email=p.email, password=pw, display_name=p.name, email_verified=True).uid


def clear(db, uid: str) -> int:
    n = 0
    for sub in ("readings", "events", "messages"):
        for doc in db.collection("users").document(uid).collection(sub).list_documents():
            doc.delete()
            n += 1
    return n


def seed(db, auth, now: datetime) -> None:
    passwords: dict[str, str] = {}
    uid = {p.key: ensure_account(auth, p, passwords) for p in [CLINICIAN, *PATIENTS]}
    doc_uid = uid["clinician"]
    users = db.collection("users")

    users.document(doc_uid).set({"email": CLINICIAN.email, "name": CLINICIAN.name, "role": "clinician",
                                 "language": "en", "demo": True}, merge=True)
    db.collection("clinician_codes").document(CODE).set({"clinicianId": doc_uid, "name": CLINICIAN.name, "clinicianName": CLINICIAN.name})

    rnd = random.Random(7)
    readings = plan(now)
    for p in PATIENTS:
        pid = uid[p.key]
        signed_up = now - timedelta(days=30)
        users.document(pid).set({"email": p.email, "name": p.name, "role": "patient", "assignedClinicianId": doc_uid,
                                 "language": "en", "termsVersion": TERMS_VERSION, "termsAcceptedAt": signed_up,
                                 "researchConsent": False, "researchConsentAt": signed_up, "demo": True,
                                 **p.profile}, merge=True)
        removed = clear(db, pid)
        batch, count = db.batch(), 0
        ref_of = {}
        for r in readings[p.key]:
            ref = users.document(pid).collection("readings").document()
            ref_of[id(r)] = ref.id
            batch.set(ref, reading_doc(r, rnd))
            count += 1
        batch.commit()

        # rule events for the yellow readings, as the phone writes them with the reading
        for r in readings[p.key]:
            if not is_yellow_bp(r):
                continue
            rid = ref_of[id(r)]
            ev = {"patientId": pid, "clinicianId": doc_uid, "tsTriggered": r["ts"] + timedelta(minutes=2),
                  "triggerSource": "rule", "tier": "yellow", "score": None, "readingId": rid, "trigger": trigger(r),
                  "thresholdVersion": HOME_VERSION, "modelVersion": None, "status": "open",
                  "notifiedAt": r["ts"] + timedelta(minutes=3)}
            if now - r["ts"] > timedelta(days=3):     # old: reviewed, and the patient told
                ev.update(status="closed", tsReviewed=r["ts"] + timedelta(hours=14), reviewedBy=doc_uid,
                          verdict="not_significant", action="advice",
                          comment="Measured just after walking back from the market. Advised to sit for five "
                                  "minutes before measuring.",
                          patientNotifiedAt=r["ts"] + timedelta(hours=14, minutes=1))
            users.document(pid).collection("events").document(f"rule_{rid}").set(ev)

        if p is ESTHER:
            msgs = users.document(pid).collection("messages")
            t0 = (now.astimezone(DOUALA) - timedelta(days=4)).replace(hour=18, minute=12).astimezone(timezone.utc)
            msgs.document().set({"senderId": doc_uid, "senderRole": "clinician", "senderName": CLINICIAN.name,
                                 "text": "Good evening Mrs Mbella. Your readings this week are within your "
                                         "targets. Keep measuring morning and evening.",
                                 "timestamp": t0, "readAt": t0 + timedelta(minutes=40)})
            t1 = t0 + timedelta(minutes=41)
            msgs.document().set({"senderId": pid, "senderRole": "patient", "senderName": p.name,
                                 "text": "Thank you doctor, I will.", "timestamp": t1,
                                 "readAt": t1 + timedelta(hours=13)})
        print(f"{p.name:16} {count:3} readings ({removed} old documents removed)")

    if passwords:
        f = SECRETS / "demo_accounts.txt"
        with f.open("a", encoding="utf-8") as out:
            for email, pw in passwords.items():
                out.write(f"{email}\t{pw}\n")
        print(f"new accounts: passwords added to {f}")
    print(f"clinician {CLINICIAN.name}: code {CODE}; history ends {now.astimezone(DOUALA):%d/%m %H:%M} (Douala)")


def delete_all(db, auth) -> None:
    for p in [CLINICIAN, *PATIENTS]:
        try:
            u = auth.get_user_by_email(p.email).uid
        except auth.UserNotFoundError:
            continue
        clear(db, u)
        db.collection("users").document(u).delete()
        auth.delete_user(u)
        print("deleted", p.email)
    db.collection("clinician_codes").document(CODE).delete()


def remove_one(db, auth, email: str) -> None:
    """Deletes one invented account (e.g. the one created on camera at sign-up)."""
    if not email.endswith("@example.com"):
        raise SystemExit("only invented @example.com accounts can be removed here")
    try:
        u = auth.get_user_by_email(email).uid
    except auth.UserNotFoundError:
        print("no such account:", email)
        return
    clear(db, u)
    db.collection("users").document(u).delete()
    auth.delete_user(u)
    print("deleted", email)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--credentials", default=str(SECRETS / "service-account.json"))
    ap.add_argument("--plan", action="store_true", help="print the readings and write nothing")
    ap.add_argument("--delete", action="store_true", help="remove the demo accounts and their data")
    ap.add_argument("--remove", metavar="EMAIL", help="remove one invented @example.com account and its data")
    a = ap.parse_args()
    now = datetime.now(timezone.utc)
    if a.plan:
        for who, rs in plan(now).items():
            print(f"# {who}: {len(rs)} readings")
            for r in rs:
                t = r["ts"].astimezone(DOUALA)
                bp = f"{r['sbp']}/{r['dbp']} hr {r['hr']}" if r.get("sbp") else "-"
                g = f"{r['glucose']} {r['context']}" if r.get("glucose") else ""
                print(f"{t:%a %d/%m %H:%M}  {bp:16} {g}")
        return
    import firebase_admin
    from firebase_admin import auth, credentials, firestore
    firebase_admin.initialize_app(credentials.Certificate(a.credentials))
    db = firestore.client()
    if a.remove:
        remove_one(db, auth, a.remove)
    elif a.delete:
        delete_all(db, auth)
    else:
        seed(db, auth, now)


if __name__ == "__main__":
    main()
