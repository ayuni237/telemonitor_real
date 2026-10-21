"""Server functions — thesis ch.4, Table "Server functions specified" (tab:triggers).

A local worker, run on the development machine like the risk service (hosting
is outside the thesis). Each cycle, for every patient:

  measurement check   new reading -> quality flag (quality.py, the controls of
                      the research pipeline) written on the reading;
  escalation          a new reading at yellow or red -> rule event, unless the
                      value is impossible or suspect;
  scoring             the latest reading -> rule floor and model (app.assess,
                      the code of the endpoint); a model that raises the tier
                      -> model event;
  notification        each new event once, by level and recipient (Table
                      "Notification by level"); the patient is never told to
                      change a dose;
  non-transmission    no reading for longer than the checkup period -> event,
                      and a reminder to the patient;
  queue-age sweep     an event left open too long -> escalated to the
                      clinician's named alternate, both notified;
  verdict             a closed event -> the patient is told it was reviewed.

Event ids are derived from what raised them (rule_<reading>, model_<reading>,
nontx_<last reading>), the same ids the apps use, so a function run by both
the phone and the worker cannot create two events. SMS fallback is not built.

    python -m telemonitor.serve.worker --credentials service-account.json [--once]
"""
from __future__ import annotations

import argparse
import logging
import os
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Protocol

import numpy as np
import pandas as pd
import yaml

from .. import quality as Q

os.environ.setdefault("TELEMONITOR_SERVE", "0")   # the worker builds no web app
from .app import ROOT, SERVE_CFG, TIERS, NoPlausibleReading, Reading, RiskRequest, assess, load_checked

CFG_PATH = ROOT / "configs" / "worker.yaml"
SCORING_WINDOW = timedelta(hours=96)     # the risk card's window (RiskAssessmentService.window)
CHANNELS = ("sbp", "dbp", "hr", "glucose")
log = logging.getLogger("telemonitor.worker")


class _ServerTime:
    """Placeholder for the server timestamp, resolved by the store."""

    def __repr__(self):
        return "SERVER_TIME"


SERVER_TIME = _ServerTime()
Doc = tuple[str, dict]


class Store(Protocol):
    """The part of Firestore the worker uses (FirestoreStore; a fake in the tests)."""

    def patients(self) -> list[Doc]: ...
    def user(self, uid: str) -> dict | None: ...
    def readings(self, uid: str, measured_after: datetime) -> list[Doc]: ...   # oldest first
    def last_reading(self, uid: str) -> Doc | None: ...
    def events(self, uid: str) -> list[Doc]: ...
    def create_event(self, uid: str, event_id: str, data: dict) -> bool: ...   # False if it exists
    def update_event(self, uid: str, event_id: str, data: dict) -> None: ...
    def update_reading(self, uid: str, reading_id: str, data: dict) -> None: ...
    def push(self, uid: str, title: str, body: str) -> int: ...


def load_config(path: Path = CFG_PATH) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf8"))


def pseudonym(uid: str) -> str:
    """As on the queue row (queue_logic.dart): random account id, not identity."""
    return f"P-{uid[:6].upper()}"


def describe(trigger: dict) -> str:
    parts = []
    if trigger.get("sbp") is not None:
        parts.append(f"{trigger['sbp']}/{trigger['dbp']} mmHg")
    if trigger.get("hr") is not None:
        parts.append(f"pulse {trigger['hr']}")
    if trigger.get("glucose") is not None:
        parts.append(f"glucose {trigger['glucose']} mmol/L")
    return ", ".join(parts) or "no values"


def standing(docs: list[Doc]) -> list[Doc]:
    """Readings no correction supersedes (Reading.effective in the app)."""
    superseded = {d.get("supersedes") for _, d in docs if d.get("supersedes")}
    return [(i, d) for i, d in docs if i not in superseded]


def quality_flags(uid: str, docs: list[Doc]) -> dict[str, str]:
    """One flag per reading from the controls of quality.py, worst first."""
    if not docs:
        return {}
    df = pd.DataFrame([{"patient": uid, "date": d["timestamp"], **{c: d.get(c) for c in CHANNELS}}
                       for _, d in docs], index=[i for i, _ in docs]).astype({c: float for c in CHANNELS})
    f = Q.check(df).flags
    order = [("out_of_range", [c for c in f if c.startswith("out_of_range") or c == "incoherent_bp"]),
             ("unit_suspect", ["unit_suspect_glucose"]),
             ("duplicate", ["duplicate"]),
             ("carried_forward", [c for c in f if c.startswith("carried_forward")]),
             ("extreme", [c for c in f if c.startswith("extreme")])]
    out = {}
    for rid in df.index:
        out[rid] = next((name for name, cols in order if cols and bool(f.loc[rid, cols].any())), "ok")
    return out


def event_data(uid: str, clinician: str | None, source: str, tier: str, trigger: dict, threshold_version: str,
               reading_id: str | None = None, score: float | None = None, model_version: str | None = None) -> dict:
    """Same fields as ClinicalEvent.newData in the app."""
    return {"patientId": uid, "clinicianId": clinician, "tsTriggered": SERVER_TIME, "triggerSource": source,
            "tier": tier, "score": score, "readingId": reading_id, "trigger": trigger,
            "thresholdVersion": threshold_version, "modelVersion": model_version, "status": "open"}


def trigger_of(d: dict) -> dict:
    return {"sbp": d.get("sbp"), "dbp": d.get("dbp"), "hr": d.get("hr"), "glucose": d.get("glucose"),
            "context": d.get("context", ""), "measuredAt": d["timestamp"]}


def _sex_code(sex) -> str | None:
    return {"M": "M", "Male": "M", "F": "F", "Female": "F"}.get(sex)


@dataclass
class Worker:
    store: Store
    table: object
    arts: dict
    cfg: dict

    # ------------------------------------------------------------- one cycle
    def cycle(self, now: datetime | None = None) -> dict[str, int]:
        now = now or datetime.now(timezone.utc)
        stats: Counter = Counter()
        for uid, profile in self.store.patients():
            try:
                self._new_readings(uid, profile, now, stats)
                self._non_transmission(uid, profile, now, stats)
                self._events(uid, profile, now, stats)
            except Exception:                      # one patient's failure must not stop the others
                log.exception("patient %s", pseudonym(uid))
                stats["errors"] += 1
        return dict(stats)

    def _recent(self, t: datetime | None, now: datetime) -> bool:
        """Within max_age_hours: old enough items are backlog, not alerts."""
        return t is not None and now - t <= timedelta(hours=self.cfg["max_age_hours"])

    def level(self, d: dict) -> float:
        row = pd.DataFrame([{c: d.get(c) for c in CHANNELS}], dtype=float)
        return float(self.table.label(row)["y"].iloc[0])

    def rule_tier(self, d: dict) -> str:
        lv = self.level(d)
        return SERVE_CFG["rule_floor"][int(lv)] if np.isfinite(lv) else "green"

    # ------------------------------------------------------------- measurement check, escalation, scoring
    def _new_readings(self, uid: str, profile: dict, now: datetime, stats: Counter) -> None:
        docs = self.store.readings(uid, now - timedelta(days=self.cfg["quality_window_days"]))
        new = [(i, d) for i, d in docs if "qualityCheckedAt" not in d]
        if not new:
            return
        keep = standing(docs)
        kept_ids = {i for i, _ in keep}
        flags = quality_flags(uid, keep)
        latest = max(keep, key=lambda x: x[1]["timestamp"])[0] if keep else None
        clinician = profile.get("assignedClinicianId")
        for rid, d in new:
            update = {"qualityCheckedAt": SERVER_TIME}
            if rid in kept_ids:
                flag = flags.get(rid, "ok")
                update["qualityFlag"] = flag
                stats["readings_checked"] += 1
                if flag not in ("out_of_range", "unit_suspect", "duplicate") and self._recent(d.get("recordedAt"), now):
                    tier = self.rule_tier(d)
                    if tier != "green" and self.store.create_event(
                            uid, f"rule_{rid}", event_data(uid, clinician, "rule", tier, trigger_of(d),
                                                           self.table.version, reading_id=rid)):
                        stats["rule_events"] += 1
                    if rid == latest:
                        self._score(uid, profile, rid, d, keep, stats)
            self.store.update_reading(uid, rid, update)

    def _score(self, uid: str, profile: dict, rid: str, d: dict, keep: list[Doc], stats: Counter) -> None:
        window = [x for _, x in keep if d["timestamp"] - x["timestamp"] <= SCORING_WINDOW]
        req = RiskRequest(readings=[Reading(time=x["timestamp"], **{c: x.get(c) for c in CHANNELS}) for x in window],
                          age=profile.get("age"), sex=_sex_code(profile.get("sex")))
        try:
            out = assess(req, self.table, self.arts)
        except NoPlausibleReading:
            return
        stats["scored"] += 1
        tier, rule = out["tier"], out["rule"]["tier"]
        if tier == "green" or TIERS.index(tier) <= TIERS.index(rule):
            return
        raising = [c for c in out["conditions"].values() if c["tier"] == tier]
        data = event_data(uid, profile.get("assignedClinicianId"), "model", tier, trigger_of(d), self.table.version,
                          reading_id=rid, score=max(c["alert_probability"] for c in raising),
                          model_version=", ".join(c["model"] for c in out["conditions"].values()))
        if self.store.create_event(uid, f"model_{rid}", data):
            stats["model_events"] += 1

    # ------------------------------------------------------------- non-transmission sweep
    def _non_transmission(self, uid: str, profile: dict, now: datetime, stats: Counter) -> None:
        last = self.store.last_reading(uid)
        if last is None:
            return
        rid, d = last
        days = int(profile.get("checkupPeriodDays") or self.cfg["default_checkup_period_days"])
        if now - d["timestamp"] <= timedelta(days=days):
            return
        data = event_data(uid, profile.get("assignedClinicianId"), "non_transmission", "yellow",
                          {"lastReadingAt": d["timestamp"], "checkupPeriodDays": days}, self.table.version,
                          reading_id=rid)
        if self.store.create_event(uid, f"nontx_{rid}", data):
            stats["non_transmission_events"] += 1

    # ------------------------------------------------------------- notification, queue age, verdict
    def _events(self, uid: str, profile: dict, now: datetime, stats: Counter) -> None:
        n = self.cfg["notify"]
        clinician = profile.get("assignedClinicianId")
        for eid, e in self.store.events(uid):
            trig = e.get("trigger") or {}
            fields = {"pseudonym": pseudonym(uid), "trigger": describe(trig), "tier": e.get("tier", "")}
            if e.get("status") == "open":
                if "notifiedAt" not in e and not self._recent(e.get("tsTriggered"), now):
                    self.store.update_event(uid, eid, {"notifiedAt": SERVER_TIME})   # backlog: marked, not sent
                elif "notifiedAt" not in e:
                    if e.get("triggerSource") == "non_transmission":
                        days = trig.get("checkupPeriodDays", self.cfg["default_checkup_period_days"])
                        stats["pushes"] += self.store.push(uid, "TeleMonitor",
                                                           n["non_transmission"]["patient"].format(days=days))
                    else:
                        msgs = n.get(e.get("tier"), {})
                        if msgs.get("patient"):
                            stats["pushes"] += self.store.push(uid, "TeleMonitor", msgs["patient"])
                        if msgs.get("clinician") and clinician:
                            stats["pushes"] += self.store.push(clinician, "TeleMonitor alert",
                                                               msgs["clinician"].format(**fields))
                    self.store.update_event(uid, eid, {"notifiedAt": SERVER_TIME})
                    stats["events_notified"] += 1
                limit = self.cfg["queue_age_hours"].get(e.get("tier"))
                age_h = (now - e["tsTriggered"]).total_seconds() / 3600
                if limit is not None and "escalatedAt" not in e and age_h >= limit:
                    alternate = (self.store.user(clinician) or {}).get("alternateClinicianId") if clinician else None
                    self.store.update_event(uid, eid, {"escalatedAt": SERVER_TIME, "escalatedTo": alternate})
                    text = n["escalation"]["clinician"].format(age=int(age_h), **fields)
                    for to in {clinician, alternate} - {None}:
                        stats["pushes"] += self.store.push(to, "TeleMonitor escalation", text)
                    stats["escalated"] += 1
            elif e.get("status") == "closed" and "patientNotifiedAt" not in e:
                if not self._recent(e.get("tsReviewed"), now):
                    self.store.update_event(uid, eid, {"patientNotifiedAt": SERVER_TIME})
                    continue
                when = e["tsTriggered"].strftime("%d/%m/%Y")
                stats["pushes"] += self.store.push(uid, "TeleMonitor", n["verdict"]["patient"].format(date=when))
                self.store.update_event(uid, eid, {"patientNotifiedAt": SERVER_TIME})
                stats["verdicts_notified"] += 1


# ----------------------------------------------------------------- Firestore
class FirestoreStore:
    """Store backed by the Firebase Admin SDK (bypasses the security rules: the
    worker is trusted, like the server functions of the production design)."""

    def __init__(self, credentials_path: str | Path):
        import firebase_admin
        from firebase_admin import credentials, firestore, messaging
        app = firebase_admin.initialize_app(credentials.Certificate(str(credentials_path)))
        self.db, self.fs, self.messaging = firestore.client(app), firestore, messaging

    def _v(self, data: dict) -> dict:
        return {k: (self.fs.SERVER_TIMESTAMP if v is SERVER_TIME else v) for k, v in data.items()}

    def _user(self, uid):
        return self.db.collection("users").document(uid)

    def patients(self):
        return [(d.id, d.to_dict()) for d in self.db.collection("users").where("role", "==", "patient").stream()]

    def user(self, uid):
        snap = self._user(uid).get()
        return snap.to_dict() if snap.exists else None

    def readings(self, uid, measured_after):
        q = self._user(uid).collection("readings").where("timestamp", ">", measured_after).order_by("timestamp")
        return [(d.id, d.to_dict()) for d in q.stream()]

    def last_reading(self, uid):
        q = self._user(uid).collection("readings").order_by("timestamp", direction="DESCENDING").limit(1)
        docs = list(q.stream())
        return (docs[0].id, docs[0].to_dict()) if docs else None

    def events(self, uid):
        q = self._user(uid).collection("events").order_by("tsTriggered", direction="DESCENDING").limit(200)
        return [(d.id, d.to_dict()) for d in q.stream()]

    def create_event(self, uid, event_id, data):
        from google.api_core.exceptions import AlreadyExists
        try:
            self._user(uid).collection("events").document(event_id).create(self._v(data))
            return True
        except AlreadyExists:
            return False

    def update_event(self, uid, event_id, data):
        self._user(uid).collection("events").document(event_id).update(self._v(data))

    def update_reading(self, uid, reading_id, data):
        self._user(uid).collection("readings").document(reading_id).update(self._v(data))

    def push(self, uid, title, body):
        tokens = (self.user(uid) or {}).get("fcmTokens") or []
        if not tokens:
            return 0
        res = self.messaging.send_each_for_multicast(self.messaging.MulticastMessage(
            tokens=tokens, notification=self.messaging.Notification(title=title, body=body)))
        dead = [t for t, r in zip(tokens, res.responses) if not r.success]
        if dead:                                   # uninstalled app or expired token
            self._user(uid).update({"fcmTokens": self.fs.ArrayRemove(dead)})
        return res.success_count


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--credentials", required=True, help="Firebase service-account JSON (never commit it)")
    ap.add_argument("--artifacts", help="model artifacts folder (default: artifacts/)")
    ap.add_argument("--once", action="store_true", help="run one cycle and stop")
    a = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    cfg = load_config()
    table, arts = load_checked(Path(a.artifacts) if a.artifacts else None)
    log.info("thresholds %s, models: %s", table.version, ", ".join(x.version for x in arts.values()) or "none (rule only)")
    worker = Worker(FirestoreStore(a.credentials), table, arts, cfg)
    while True:
        t0 = time.time()
        stats = worker.cycle()
        log.info("cycle done in %.1f s: %s", time.time() - t0, stats or "nothing new")
        if a.once:
            return
        time.sleep(max(1.0, cfg["interval_seconds"] - (time.time() - t0)))


if __name__ == "__main__":
    main()
