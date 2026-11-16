"""Server functions — thesis ch.4, Table "Server functions specified" (tab:triggers).

A local worker, run on the development machine like the risk service (hosting
is outside the thesis). Each cycle, for every patient:

  measurement check   new reading -> quality flag (quality.py, the controls of
                      the research pipeline) written on the reading;
  escalation          a new reading at yellow or red under the home triage
                      (home_protocol.py, the rule of the application) -> rule
                      event, unless the value is impossible or suspect;
  scoring             the latest reading -> rule floor and model (app.assess,
                      the code of the endpoint); a model that raises the tier
                      -> model event;
  notification        each new event once, by level and recipient (Table
                      "Notification by level"); the patient is never told to
                      change a dose;
  non-transmission    no reading for longer than the checkup period -> event,
                      and a reminder to the patient, repeated while the
                      silence lasts;
  queue-age sweep     an event left open too long -> escalated to the
                      clinician's named alternate, both notified;
  verdict             a closed event -> the patient is told it was reviewed;
  messages            a message still unread a few seconds after it arrived ->
                      the recipient is told, without its text (a locked screen
                      shows it); new messages come from a Firestore listener,
                      so the delay is seconds and only new messages are read;
  confirmation email  a patient asks for the link confirming their address
                      (mail_requests/{uid}) -> TeleMonitor's own email, sent
                      through the SMTP account of secrets/smtp.json (mail.py);
                      without that file the app uses Firebase's email;
  password reset      "Forgot password?" (password_resets/{address}, asked
                      signed out) -> the same, only for an existing account,
                      to the account's own address, a few times a day at most.

Event ids are derived from what raised them (rule_<reading>, model_<reading>,
nontx_<last reading>), the same ids the apps use, so a function run by both
the phone and the worker cannot create two events. SMS fallback is not built.

    python -m telemonitor.serve.worker --credentials service-account.json [--once]
    python -m telemonitor.serve.worker --credentials service-account.json --test-push EMAIL
    python -m telemonitor.serve.worker --credentials service-account.json --test-mail EMAIL
"""
from __future__ import annotations

import argparse
import logging
import os
import threading
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Protocol

import pandas as pd
import yaml

from .. import quality as Q
from ..home_protocol import HomeProtocol, HomeReading, load_home_protocol
from .mail import Mailer, password_reset_email, verification_email

os.environ.setdefault("TELEMONITOR_SERVE", "0")   # the worker builds no web app
from .app import ROOT, TIERS, NoPlausibleReading, Reading, RiskRequest, assess, load_checked

CFG_PATH = ROOT / "configs" / "worker.yaml"
SCORING_WINDOW = timedelta(hours=96)     # the risk card's window (RiskAssessmentService.window)
HOME_TIERS = ("green", "yellow", "red")  # home levels 0, 1, 2 map one to one to tiers
CHANNELS = ("sbp", "dbp", "hr", "glucose")
ALERT_CHANNEL = "alerts"                 # Android channel of the app (MainActivity.kt), high importance
MESSAGE_CHANNEL = "messages"             # its own channel: a person may silence messages, not alerts
TICK_SECONDS = 5                         # main loop: messages at every tick, the cycle every interval_seconds
WATCH_RETRY_SECONDS = 60                 # a listener that failed (no network, index being built)
WATCH_RENEW_SECONDS = 12 * 3600          # a new listener now and then: the window moves on, a stale one is replaced
MAIL_RETRIES = 3                         # an email that failed (SMTP down) is tried again a minute later, twice
TEST_PUSH = "Test notification: alerts from TeleMonitor reach this phone."
log = logging.getLogger("telemonitor.worker")


class _ServerTime:
    """Placeholder for the server timestamp, resolved by the store."""

    def __repr__(self):
        return "SERVER_TIME"


SERVER_TIME = _ServerTime()
Doc = tuple[str, dict]
MessageChange = tuple[str, str, "dict | None"]   # patient, message id, its data (None: removed)


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
    def update_message(self, uid: str, message_id: str, data: dict) -> None: ...
    def push(self, uid: str, title: str, body: str, channel: str = ALERT_CHANNEL,
             data: dict | None = None, tag: str | None = None) -> int: ...
    def account(self, uid: str) -> tuple[str | None, bool] | None: ...      # Firebase Auth: email, verified
    def verification_link(self, email: str) -> str: ...
    def update_mail_request(self, uid: str, data: dict) -> None: ...
    def account_by_email(self, email: str) -> tuple[str, str, bool] | None: ...   # uid, email, disabled
    def password_reset_link(self, email: str) -> str: ...
    def update_password_reset(self, address: str, data: dict | None) -> None: ...   # None: delete it


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
    # Q.check treats one row per chart slot; here a blood-pressure reading and a glucose
    # reading may share a minute, so a duplicate needs the same time and the same values
    f["duplicate"] = df.duplicated(["patient", "date", *CHANNELS], keep="first").reindex(f.index, fill_value=False)
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
class _Message:
    role: str            # the sender's: 'patient' or 'clinician'
    sent: datetime
    read: bool
    notified: bool
    seen: datetime       # when the worker first saw it


class Inbox:
    """The messages of the last max_age_hours, as the listener reports them.

    The listener calls apply() from its own thread and the main loop calls
    due(), hence the lock."""

    def __init__(self):
        self._lock = threading.Lock()
        self._msgs: dict[tuple[str, str], _Message] = {}

    def apply(self, changes: list[MessageChange], seen: datetime) -> None:
        with self._lock:
            for patient, mid, d in changes:
                key = (patient, mid)
                if d is None:
                    self._msgs.pop(key, None)
                    continue
                old = self._msgs.get(key)
                self._msgs[key] = _Message(
                    role="clinician" if d.get("senderRole") == "clinician" else "patient",
                    sent=d.get("timestamp") or seen, read=d.get("readAt") is not None,
                    notified="notifiedAt" in d or (old is not None and old.notified),
                    seen=old.seen if old else seen)

    def due(self, now: datetime, delay: timedelta, max_age: timedelta) -> list[tuple[str, str, list[str], int]]:
        """Per conversation and side: the messages still unread [delay] after the
        worker saw them and not yet notified, and how many of that side's
        messages are unread in all (patient, sender's role, ids, unread)."""
        with self._lock:
            for key in [k for k, m in self._msgs.items() if now - m.sent > max_age]:
                del self._msgs[key]
            due, unread = defaultdict(list), Counter()
            for (patient, mid), m in self._msgs.items():
                if m.read:
                    continue
                unread[patient, m.role] += 1
                if not m.notified and now - m.seen >= delay:
                    due[patient, m.role].append(mid)
            return [(p, r, sorted(ids), unread[p, r]) for (p, r), ids in sorted(due.items())]

    def notified(self, patient: str, ids: list[str]) -> None:
        with self._lock:
            for mid in ids:
                if (m := self._msgs.get((patient, mid))) is not None:
                    m.notified = True


def _wanted(d: dict) -> bool:
    """A request the worker has not answered: asked again since the last email."""
    asked, sent = d.get("requestedAt"), d.get("sentAt")
    return asked is not None and (sent is None or sent < asked)


class MailRequests:
    """Email requests reported by a listener, until handled (thread-safe, like
    Inbox); keyed by account (confirmation) or by address (password reset)."""

    def __init__(self):
        self._lock = threading.Lock()
        self._pending: dict[str, dict] = {}
        self._not_before: dict[str, datetime] = {}
        self._attempts: Counter = Counter()

    def apply(self, changes: list[tuple[str, dict | None]]) -> None:
        with self._lock:
            for uid, d in changes:
                if d is not None and _wanted(d):
                    self._pending[uid] = d
                else:
                    self._pending.pop(uid, None)

    def take(self, now: datetime) -> list[tuple[str, dict]]:
        with self._lock:
            due = [(u, d) for u, d in self._pending.items() if self._not_before.get(u, now) <= now]
            for u, _ in due:
                del self._pending[u]
            return due

    def done(self, uid: str) -> None:
        with self._lock:
            self._attempts.pop(uid, None)
            self._not_before.pop(uid, None)

    def retry(self, uid: str, d: dict, now: datetime) -> None:
        with self._lock:
            self._attempts[uid] += 1
            if self._attempts[uid] < MAIL_RETRIES:
                self._pending.setdefault(uid, d)
                self._not_before[uid] = now + timedelta(seconds=WATCH_RETRY_SECONDS)


@dataclass
class Worker:
    store: Store
    table: object                    # research labels (model and its version check)
    arts: dict
    cfg: dict
    home: HomeProtocol = field(default_factory=load_home_protocol)   # home triage of the rule events
    mailer: Mailer | None = None     # SMTP account of the confirmation emails (mail.py); None: no email
    resets_sent: dict = field(default_factory=lambda: defaultdict(list))   # address -> times sent

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

    @staticmethod
    def home_reading(d: dict) -> HomeReading:
        return HomeReading(d["timestamp"], d.get("sbp"), d.get("dbp"), d.get("hr"), d.get("glucose"),
                           d.get("context", ""))

    def rule_tier(self, d: dict) -> str:
        """Tier of a reading under the home triage (the application's rule; thesis ch.4 §triage)."""
        lv = self.home.level(self.home_reading(d))
        return HOME_TIERS[lv] if lv is not None else "green"

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
                                                           self.home.version, reading_id=rid)):
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
        # the rule the model may raise is the home triage of the same window, as in the app
        home_level = self.home.latest_level([self.home_reading(x) for x in window])
        rule = TIERS[max(TIERS.index(out["rule"]["tier"]), home_level or 0)]
        tier = TIERS[max(TIERS.index(out["tier"]), TIERS.index(rule))]
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
                          {"lastReadingAt": d["timestamp"], "checkupPeriodDays": days}, self.home.version,
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
                elif e.get("triggerSource") == "non_transmission":
                    # repeated reminders while the silence lasts (thesis ch.4 §The decision flow)
                    last = e.get("lastReminderAt") or e.get("notifiedAt")
                    if last is not None and now - last >= timedelta(hours=self.cfg["reminder_interval_hours"]):
                        days = trig.get("checkupPeriodDays", self.cfg["default_checkup_period_days"])
                        stats["pushes"] += self.store.push(uid, "TeleMonitor",
                                                           n["non_transmission"]["patient"].format(days=days))
                        self.store.update_event(uid, eid, {"lastReminderAt": SERVER_TIME})
                        stats["reminders"] += 1
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

    # ------------------------------------------------------------- messages
    def messages(self, inbox: Inbox, now: datetime | None = None) -> dict[str, int]:
        """A push to the recipient of the messages still unread message_delay_seconds
        after they arrived: the assigned clinician for a patient's message, the
        patient for a clinician's. An open conversation marks them read at once,
        so it brings no push. Who wrote, never what: a locked screen shows it."""
        now = now or datetime.now(timezone.utc)
        stats: Counter = Counter()
        texts = self.cfg["notify"]["message"]
        for patient, role, ids, unread in inbox.due(now, timedelta(seconds=self.cfg["message_delay_seconds"]),
                                                    timedelta(hours=self.cfg["max_age_hours"])):
            # marked first: a failed write must not bring the same push at every tick
            inbox.notified(patient, ids)
            try:
                if role == "clinician":
                    to, text = patient, texts["patient"]
                else:
                    to, text = (self.store.user(patient) or {}).get("assignedClinicianId"), texts["clinician"]
                if to:
                    body = text[0 if unread == 1 else 1].format(count=unread, pseudonym=pseudonym(patient))
                    # one notification per conversation: the next one replaces it, with the new count
                    stats["pushes"] += self.store.push(to, "TeleMonitor", body, channel=MESSAGE_CHANNEL,
                                                       data={"open": "messages", "patientId": patient},
                                                       tag=f"messages-{patient}")
                for mid in ids:
                    self.store.update_message(patient, mid, {"notifiedAt": SERVER_TIME})
                stats["messages_notified"] += len(ids)
            except Exception:
                log.exception("messages of %s", pseudonym(patient))
                stats["errors"] += 1
        return dict(stats)

    # ------------------------------------------------------------- confirmation emails
    def emails(self, requests: MailRequests, now: datetime | None = None) -> dict[str, int]:
        """Answers each request for the link confirming the account's address."""
        return self._answer(requests, now, self._confirmation, "confirmation email")

    def resets(self, requests: MailRequests, now: datetime | None = None) -> dict[str, int]:
        """Answers each request for the link choosing a new password."""
        return self._answer(requests, now, self._reset, "password reset email")

    def _answer(self, requests: MailRequests, now: datetime | None, answer, what: str) -> dict[str, int]:
        if self.mailer is None:
            return {}
        now = now or datetime.now(timezone.utc)
        stats: Counter = Counter()
        for key, req in requests.take(now):
            try:
                stats[answer(key, req, now)] += 1
                requests.done(key)
            except Exception:
                log.exception("%s not sent", what)      # no address or account id in the log
                requests.retry(key, req, now)
                stats["errors"] += 1
        return dict(stats)

    def _confirmation(self, uid: str, req: dict, now: datetime) -> str:
        # the address comes from Firebase Auth, never from the request
        account = self.store.account(uid) if self._recent(req.get("requestedAt"), now) else None
        if not self._recent(req.get("requestedAt"), now):
            outcome = "emails_expired"                 # asked while the worker was stopped, long ago
        elif account is None or not account[0]:
            outcome = "emails_no_address"
        elif account[1]:
            outcome = "emails_already_confirmed"
        else:
            name = (self.store.user(uid) or {}).get("name")
            self.mailer.send(account[0], *verification_email(name, self.store.verification_link(account[0])))
            outcome = "emails_sent"
        self.store.update_mail_request(uid, {"sentAt": SERVER_TIME, "outcome": outcome})
        return outcome

    def _reset(self, address: str, req: dict, now: datetime) -> str:
        # asked signed out, so anyone may ask for any address: the link goes only to an
        # existing account's own address, a few times a day at most (rules: once a minute)
        if not self._recent(req.get("requestedAt"), now):
            outcome = "resets_expired"
        elif (account := self.store.account_by_email(address)) is None:
            self.store.update_password_reset(address, None)   # no trace of addresses without an account
            return "resets_no_account"
        elif account[2]:
            outcome = "resets_disabled"
        else:
            day = now - timedelta(days=1)
            sent = self.resets_sent[address] = [t for t in self.resets_sent[address] if t > day]
            if len(sent) >= self.cfg["password_resets_per_day"]:
                outcome = "resets_limited"
            else:
                uid, email = account[0], account[1]
                name = (self.store.user(uid) or {}).get("name")
                self.mailer.send(email, *password_reset_email(name, self.store.password_reset_link(email)))
                sent.append(now)
                outcome = "resets_sent"
        self.store.update_password_reset(address, {"sentAt": SERVER_TIME, "outcome": outcome})
        return outcome


# ----------------------------------------------------------------- listeners
class Listening:
    """One Firestore listener kept open by the main loop: opened again when it
    stops (no network, index being built) and renewed now and then."""

    def __init__(self, name: str, open_listener):
        self.name, self._open = name, open_listener
        self._watch, self._retry_at, self._renew_at = None, 0.0, 0.0

    @property
    def active(self) -> bool:
        return self._watch is not None and self._watch.is_active

    def keep(self, t: float) -> None:
        if self.active and t < self._renew_at:
            return
        if self._watch is not None:
            try:
                self._watch.unsubscribe()
            except Exception:
                pass
            self._watch = None
        if t < self._retry_at:
            return
        self._retry_at = t + WATCH_RETRY_SECONDS
        try:
            self._watch = self._open()
            self._renew_at = t + WATCH_RENEW_SECONDS
            log.info("listening to %s", self.name)
        except Exception as e:
            log.error("%s: cannot listen (%s); trying again in %d s", self.name, e, WATCH_RETRY_SECONDS)


# ----------------------------------------------------------------- Firestore
class FirestoreStore:
    """Store backed by the Firebase Admin SDK (bypasses the security rules: the
    worker is trusted, like the server functions of the production design)."""

    def __init__(self, credentials_path: str | Path):
        import firebase_admin
        from firebase_admin import auth, credentials, firestore, messaging
        app = firebase_admin.initialize_app(credentials.Certificate(str(credentials_path)))
        self.db, self.fs, self.messaging, self.auth = firestore.client(app), firestore, messaging, auth

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

    def update_message(self, uid, message_id, data):
        self._user(uid).collection("messages").document(message_id).update(self._v(data))

    def _messages_since(self, since: datetime):
        # collection-group query: its index is in firestore.indexes.json (messages.timestamp)
        from google.cloud.firestore_v1.base_query import FieldFilter
        return self.db.collection_group("messages").where(filter=FieldFilter("timestamp", ">=", since))

    @staticmethod
    def _change(doc, removed: bool = False) -> MessageChange | None:
        owner = doc.reference.parent.parent                 # users/{patient}/messages/{id}
        if owner is None or owner.parent.id != "users":
            return None
        return owner.id, doc.reference.id, None if removed else doc.to_dict()

    def recent_messages(self, since: datetime) -> list[MessageChange]:
        return [c for d in self._messages_since(since).stream() if (c := self._change(d)) is not None]

    def watch_messages(self, since: datetime, on_change):
        """Listener on the messages sent since [since]: the first call brings them
        all, then only what changes (one read per new or changed message)."""
        q = self._messages_since(since)
        q.limit(1).get()     # fails at once, with the reason (index missing or being built)

        def callback(_docs, changes, _read_time):
            try:
                on_change([c for ch in changes
                           if (c := self._change(ch.document, ch.type.name == "REMOVED")) is not None])
            except Exception:
                log.exception("message listener")
        return q.on_snapshot(callback)

    # confirmation emails
    def account(self, uid):
        try:
            u = self.auth.get_user(uid)
        except self.auth.UserNotFoundError:
            return None
        return u.email, bool(u.email_verified)

    def verification_link(self, email):
        return self.auth.generate_email_verification_link(email)

    def update_mail_request(self, uid, data):
        self.db.collection("mail_requests").document(uid).set(self._v(data), merge=True)

    def account_by_email(self, email):
        try:
            u = self.auth.get_user_by_email(email)
        except self.auth.UserNotFoundError:
            return None
        return u.uid, u.email, bool(u.disabled)

    def password_reset_link(self, email):
        return self.auth.generate_password_reset_link(email)

    def update_password_reset(self, address, data):
        ref = self.db.collection("password_resets").document(address)
        if data is None:
            ref.delete()
        else:
            ref.set(self._v(data), merge=True)

    def watch_mail_requests(self, on_change, collection="mail_requests"):
        """Listener on the requests (mail_requests or password_resets): one
        document per account or address, so the first call reads them all, then
        one read per request."""
        def callback(_docs, changes, _read_time):
            try:
                on_change([(ch.document.id, None if ch.type.name == "REMOVED" else ch.document.to_dict())
                           for ch in changes])
            except Exception:
                log.exception("%s listener", collection)
        return self.db.collection(collection).on_snapshot(callback)

    def mail_heartbeat(self):
        """Tells the app the worker sends the emails (AuthService._workerSendsMail)."""
        self.db.collection("config").document("mail").set({"workerAt": self.fs.SERVER_TIMESTAMP})

    def uid_for_email(self, email: str) -> str | None:
        docs = list(self.db.collection("users").where("email", "==", email.strip()).limit(1).stream())
        return docs[0].id if docs else None

    def push(self, uid, title, body, channel=ALERT_CHANNEL, data=None, tag=None):
        tokens = (self.user(uid) or {}).get("fcmTokens") or []
        if not tokens:
            return 0
        m = self.messaging
        res = m.send_each_for_multicast(m.MulticastMessage(
            tokens=tokens,
            notification=m.Notification(title=title, body=body),
            data=data,       # what a tap opens (push_service.dart)
            # delivered at once even when the phone is idle, on the app's channel, with sound;
            # a notification with the same tag replaces the previous one
            android=m.AndroidConfig(priority="high", notification=m.AndroidNotification(
                channel_id=channel, default_sound=True, tag=tag)),
            apns=m.APNSConfig(payload=m.APNSPayload(aps=m.Aps(sound="default", thread_id=tag)))))
        dead = [t for t, r in zip(tokens, res.responses) if not r.success]
        if dead:                                   # uninstalled app or expired token
            self._user(uid).update({"fcmTokens": self.fs.ArrayRemove(dead)})
        return res.success_count


def test_push(store, email: str) -> int:
    """Checks the whole notification path for one account: key, token, phone."""
    uid = store.uid_for_email(email)
    if uid is None:
        log.error("no account with the email %s", email)
        return 1
    sent = store.push(uid, "TeleMonitor", TEST_PUSH)
    if sent:
        log.info("test notification sent to %d phone(s) of %s", sent, email)
        return 0
    log.error("nothing sent: no phone registered for %s. Sign in on the phone, allow notifications "
              "(Profile, Account, Notifications), then try again.", email)
    return 1


def test_mail(store, mailer: Mailer | None, email: str) -> int:
    """Checks the email path for one account: SMTP account, link, mailbox. The
    link is real: opening it confirms the address."""
    if mailer is None:
        log.error("no SMTP account: create secrets/smtp.json (see telemonitor/serve/mail.py)")
        return 1
    uid = store.uid_for_email(email)
    account = store.account(uid) if uid else None
    if account is None or not account[0]:
        log.error("no account with the email %s", email)
        return 1
    name = (store.user(uid) or {}).get("name")
    mailer.send(account[0], *verification_email(name, store.verification_link(account[0])))
    log.info("confirmation email sent to %s from %s", account[0], mailer.from_address)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--credentials", required=True, help="Firebase service-account JSON (never commit it)")
    ap.add_argument("--smtp", help="SMTP account of the emails (default: smtp.json next to the credentials)")
    ap.add_argument("--artifacts", help="model artifacts folder (default: artifacts/)")
    ap.add_argument("--once", action="store_true", help="run one cycle and stop")
    ap.add_argument("--test-push", metavar="EMAIL",
                    help="send a test notification to the phones of this account, then stop")
    ap.add_argument("--test-mail", metavar="EMAIL",
                    help="send the confirmation email to this account, then stop")
    a = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    mailer = Mailer.from_file(a.smtp or Path(a.credentials).with_name("smtp.json"))
    if a.test_push:
        return test_push(FirestoreStore(a.credentials), a.test_push)
    if a.test_mail:
        return test_mail(FirestoreStore(a.credentials), mailer, a.test_mail)
    cfg = load_config()
    table, arts = load_checked(Path(a.artifacts) if a.artifacts else None)
    log.info("thresholds %s, models: %s", table.version, ", ".join(x.version for x in arts.values()) or "none (rule only)")
    log.info("confirmation emails: %s", f"sent from {mailer.from_address}" if mailer else "by Firebase (no smtp.json)")
    store = FirestoreStore(a.credentials)
    worker = Worker(store, table, arts, cfg, mailer=mailer)
    inbox = Inbox()
    max_age = timedelta(hours=cfg["max_age_hours"])
    if a.once:
        now = datetime.now(timezone.utc)
        t0 = time.time()
        stats = Counter(worker.cycle(now))
        try:
            inbox.apply(store.recent_messages(now - max_age), now - timedelta(seconds=cfg["message_delay_seconds"]))
            stats.update(worker.messages(inbox, now))
        except Exception as e:
            log.error("messages: cannot read them (%s)", e)
        log.info("cycle done in %.1f s: %s", time.time() - t0, dict(stats) or "nothing new")
        return
    requests, resets = MailRequests(), MailRequests()
    messages = Listening("new messages", lambda: store.watch_messages(
        datetime.now(timezone.utc) - max_age, lambda ch: inbox.apply(ch, datetime.now(timezone.utc))))
    emails = [Listening("email requests", lambda: store.watch_mail_requests(requests.apply)),
              Listening("password reset requests",
                        lambda: store.watch_mail_requests(resets.apply, "password_resets"))] if mailer else []
    next_cycle = 0.0
    while True:
        t = time.time()
        for listener in (messages, *emails):
            listener.keep(t)
        if t >= next_cycle:
            next_cycle = t + cfg["interval_seconds"]
            stats = worker.cycle()
            log.info("cycle done in %.1f s: %s", time.time() - t, stats or "nothing new")
            if emails and all(listener.active for listener in emails):   # else the app sends Firebase's
                try:
                    store.mail_heartbeat()
                except Exception as e:
                    log.error("emails: heartbeat not written (%s)", e)
        if sent := worker.messages(inbox):
            log.info("messages: %s", sent)
        if mailed := worker.emails(requests):
            log.info("emails: %s", mailed)
        if mailed := worker.resets(resets):
            log.info("password resets: %s", mailed)
        time.sleep(TICK_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
