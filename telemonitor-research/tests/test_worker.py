import os
from datetime import datetime, timedelta, timezone

import numpy as np

os.environ["TELEMONITOR_SERVE"] = "0"
from telemonitor.labels import load_thresholds
from telemonitor.serve import mail as M
from telemonitor.serve import worker as W
from telemonitor.serve.artifact import Artifact

NOW = datetime(2026, 10, 20, 12, tzinfo=timezone.utc)


class FakeStore:
    def __init__(self):
        self.users = {"pat1": {"role": "patient", "assignedClinicianId": "doc1", "age": 61, "sex": "Female",
                               "name": "Aline Nkeng"},
                      "doc1": {"role": "clinician", "alternateClinicianId": "doc2"},
                      "doc2": {"role": "clinician"}}
        self.reads = {"pat1": {}}
        self.evs = {"pat1": {}}
        self.pushed = []
        self.push_options = []
        self.message_updates = []
        self.accounts = {"pat1": ("aline@example.org", False)}       # Firebase Auth: email, verified
        self.mail_updates = []
        self.disabled = set()
        self.reset_updates = []

    def _resolve(self, data):
        return {k: (NOW if v is W.SERVER_TIME else v) for k, v in data.items()}

    def add_reading(self, rid, hours_ago, **values):
        t = NOW - timedelta(hours=hours_ago)
        self.reads["pat1"][rid] = {"timestamp": t, "recordedAt": t, "context": "Fasting", **values}

    def patients(self):
        return [(u, d) for u, d in self.users.items() if d["role"] == "patient"]

    def user(self, uid):
        return self.users.get(uid)

    def readings(self, uid, measured_after):
        docs = [(i, d) for i, d in self.reads[uid].items() if d["timestamp"] > measured_after]
        return sorted(docs, key=lambda x: x[1]["timestamp"])

    def last_reading(self, uid):
        docs = sorted(self.reads[uid].items(), key=lambda x: x[1]["timestamp"])
        return docs[-1] if docs else None

    def events(self, uid):
        return list(self.evs[uid].items())

    def create_event(self, uid, event_id, data):
        if event_id in self.evs[uid]:
            return False
        self.evs[uid][event_id] = self._resolve(data)
        return True

    def update_event(self, uid, event_id, data):
        self.evs[uid][event_id].update(self._resolve(data))

    def update_reading(self, uid, reading_id, data):
        self.reads[uid][reading_id].update(self._resolve(data))

    def update_message(self, uid, message_id, data):
        self.message_updates.append((uid, message_id, self._resolve(data)))

    def account(self, uid):
        return self.accounts.get(uid)

    def verification_link(self, email):
        return f"https://telemonitor.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=X1&for={email}"

    def update_mail_request(self, uid, data):
        self.mail_updates.append((uid, self._resolve(data)))

    def account_by_email(self, email):
        uid = next((u for u, (e, _) in self.accounts.items() if e == email), None)
        return None if uid is None else (uid, email, uid in self.disabled)

    def password_reset_link(self, email):
        return f"https://telemonitor.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=R1&for={email}"

    def update_password_reset(self, address, data):
        self.reset_updates.append((address, None if data is None else self._resolve(data)))

    def push(self, uid, title, body, channel=W.ALERT_CHANNEL, data=None, tag=None):
        self.pushed.append((uid, body))
        self.push_options.append({"channel": channel, "data": data, "tag": tag})
        return 1


class HighRisk:
    """A model that always predicts a high level (for the model-escalation path)."""

    def predict_proba(self, X):
        return np.tile([0.1, 0.1, 0.5, 0.3], (len(X), 1))


def worker(store, arts=None):
    return W.Worker(store, load_thresholds(), arts or {}, W.load_config())


def test_red_reading_raises_one_rule_event_and_notifies_both():
    s = FakeStore()
    s.add_reading("r1", 2, sbp=185, dbp=110, hr=80)
    w = worker(s)
    stats = w.cycle(NOW)
    assert stats["rule_events"] == 1
    e = s.evs["pat1"]["rule_r1"]
    assert e["tier"] == "red" and e["triggerSource"] == "rule" and e["clinicianId"] == "doc1"
    assert {u for u, _ in s.pushed} == {"pat1", "doc1"}
    assert "dose" not in " ".join(b for _, b in s.pushed).lower()
    assert s.reads["pat1"]["r1"]["qualityFlag"] == "ok"
    # second cycle: nothing new, nothing sent again
    s.pushed.clear()
    assert w.cycle(NOW).get("rule_events", 0) == 0 and s.pushed == []


def test_yellow_notifies_the_patient_only():
    s = FakeStore()
    s.add_reading("r1", 1, sbp=165, dbp=95)
    worker(s).cycle(NOW)
    assert s.evs["pat1"]["rule_r1"]["tier"] == "yellow"
    assert [u for u, _ in s.pushed] == ["pat1"]


def test_an_event_already_written_by_the_phone_is_not_duplicated():
    s = FakeStore()
    s.add_reading("r1", 1, sbp=185, dbp=110)
    s.evs["pat1"]["rule_r1"] = {"status": "open", "tier": "red", "tsTriggered": NOW, "triggerSource": "rule"}
    assert worker(s).cycle(NOW).get("rule_events", 0) == 0
    assert len(s.evs["pat1"]) == 1


def test_superseded_and_backlog_readings_raise_nothing():
    s = FakeStore()
    s.add_reading("old", 3, sbp=200, dbp=120)
    s.add_reading("fix", 2, sbp=130, dbp=80, supersedes="old")
    s.add_reading("backlog", 24 * 10, sbp=190, dbp=115)        # recorded ten days ago
    worker(s).cycle(NOW)
    assert "rule_old" not in s.evs["pat1"] and "rule_backlog" not in s.evs["pat1"]
    assert "qualityFlag" not in s.reads["pat1"]["old"] and "qualityCheckedAt" in s.reads["pat1"]["old"]
    assert s.reads["pat1"]["backlog"]["qualityFlag"] == "ok"


def test_an_impossible_value_is_flagged_and_not_escalated():
    s = FakeStore()
    s.add_reading("r1", 1, sbp=120, dbp=118)                   # incoherent pair
    worker(s).cycle(NOW)
    assert s.reads["pat1"]["r1"]["qualityFlag"] == "out_of_range"
    assert s.evs["pat1"] == {}


def test_model_raising_the_tier_creates_a_model_event():
    s = FakeStore()
    for i, h in enumerate([30, 18, 6]):
        s.add_reading(f"r{i}", h, sbp=128, dbp=82, hr=75)
    m = {"version": "haemodynamic-test-0", "input": "tabular", "window_hours": 48, "feature_set": "primary"}
    stats = worker(s, {"haemodynamic": Artifact(HighRisk(), m)}).cycle(NOW)
    assert stats["model_events"] == 1
    e = s.evs["pat1"]["model_r2"]
    assert e["triggerSource"] == "model" and e["tier"] == "red" and e["score"] == 0.8
    assert e["modelVersion"] == "haemodynamic-test-0"


def test_silence_beyond_the_checkup_period_raises_non_transmission_and_a_reminder():
    s = FakeStore()
    s.add_reading("r1", 24 * 4, sbp=125, dbp=80)
    stats = worker(s).cycle(NOW)
    assert stats["non_transmission_events"] == 1
    assert s.evs["pat1"]["nontx_r1"]["triggerSource"] == "non_transmission"
    assert any(u == "pat1" and "3 days" in b for u, b in s.pushed)
    s.users["pat1"]["checkupPeriodDays"] = 7                     # a longer period: no new event
    s2 = FakeStore()
    s2.users["pat1"]["checkupPeriodDays"] = 7
    s2.add_reading("r1", 24 * 4, sbp=125, dbp=80)
    assert worker(s2).cycle(NOW).get("non_transmission_events", 0) == 0


def test_old_open_event_is_escalated_to_the_alternate_once():
    s = FakeStore()
    s.evs["pat1"]["rule_x"] = {"status": "open", "tier": "red", "triggerSource": "rule",
                              "tsTriggered": NOW - timedelta(hours=5), "notifiedAt": NOW, "trigger": {}}
    w = worker(s)
    assert w.cycle(NOW)["escalated"] == 1
    assert s.evs["pat1"]["rule_x"]["escalatedTo"] == "doc2"
    assert {u for u, _ in s.pushed} == {"doc1", "doc2"}
    assert w.cycle(NOW).get("escalated", 0) == 0


def test_verdict_informs_the_patient_once():
    s = FakeStore()
    s.evs["pat1"]["rule_x"] = {"status": "closed", "tier": "yellow", "tsTriggered": NOW - timedelta(hours=3),
                              "tsReviewed": NOW - timedelta(hours=1), "notifiedAt": NOW}
    w = worker(s)
    assert w.cycle(NOW)["verdicts_notified"] == 1
    assert s.pushed == [("pat1", "Your clinician has reviewed your alert of 20/10/2026.")]
    assert w.cycle(NOW).get("verdicts_notified", 0) == 0


def test_backlog_events_are_marked_without_sending():
    s = FakeStore()
    s.evs["pat1"]["rule_old"] = {"status": "open", "tier": "yellow", "triggerSource": "rule",
                                "tsTriggered": NOW - timedelta(hours=30), "trigger": {}}
    worker(s).cycle(NOW)
    assert s.evs["pat1"]["rule_old"]["notifiedAt"] == NOW
    assert all(u != "pat1" for u, _ in s.pushed)


def test_event_fields_match_the_app():
    data = W.event_data("p", "c", "rule", "red", {}, "v")
    app_keys = {"patientId", "clinicianId", "tsTriggered", "triggerSource", "tier", "score", "readingId",
                "trigger", "thresholdVersion", "modelVersion", "status"}       # ClinicalEvent.newData
    assert set(data) == app_keys


def test_silence_brings_a_reminder_every_day_while_it_lasts():
    s = FakeStore()
    s.evs["pat1"]["nontx_r1"] = {"status": "open", "tier": "yellow", "triggerSource": "non_transmission",
                                "tsTriggered": NOW - timedelta(hours=30), "notifiedAt": NOW - timedelta(hours=25),
                                "trigger": {"checkupPeriodDays": 3}}
    w = worker(s)
    assert w.cycle(NOW)["reminders"] == 1
    assert [u for u, _ in s.pushed if u == "pat1"] == ["pat1"]
    s.pushed.clear()
    assert w.cycle(NOW).get("reminders", 0) == 0                     # reminded less than a day ago
    assert w.cycle(NOW + timedelta(hours=25))["reminders"] == 1


def test_rule_events_follow_the_home_triage():
    s = FakeStore()
    s.add_reading("r1", 1, sbp=138, dbp=80)                            # below the hospital grade 1, above the home target
    s.add_reading("r2", 1, glucose=8.0, context="Fasting")             # above the fasting home target
    s.add_reading("r3", 1, glucose=8.0, context="After meal")          # within the after-meal target
    worker(s).cycle(NOW)
    assert s.evs["pat1"]["rule_r1"]["tier"] == "yellow"
    assert s.evs["pat1"]["rule_r1"]["thresholdVersion"] == "home-2026-10-22"
    assert s.evs["pat1"]["rule_r2"]["tier"] == "yellow"
    assert "rule_r3" not in s.evs["pat1"]


def test_a_duplicate_has_the_same_time_and_the_same_values():
    s = FakeStore()
    s.add_reading("a", 1, sbp=180, dbp=110)
    s.add_reading("b", 1, sbp=180, dbp=110)                           # same minute, same values: duplicate
    s.add_reading("c", 1, glucose=12.0, context="Fasting")            # same minute, another channel: not a duplicate
    worker(s).cycle(NOW)
    flags = {rid: s.reads["pat1"][rid]["qualityFlag"] for rid in "abc"}
    assert flags == {"a": "ok", "b": "duplicate", "c": "ok"}
    assert "rule_b" not in s.evs["pat1"] and s.evs["pat1"]["rule_c"]["tier"] == "red"


class PushStore:
    """For the test-notification command: one account, phones registered or not."""

    def __init__(self, tokens):
        self.tokens = tokens
        self.sent = []

    def uid_for_email(self, email):
        return "pat1" if email == "a@b.org" else None

    def push(self, uid, title, body):
        self.sent.append((uid, body))
        return len(self.tokens)


def test_test_push_reaches_the_registered_phones():
    s = PushStore(["t1", "t2"])
    assert W.test_push(s, "a@b.org") == 0
    assert s.sent == [("pat1", W.TEST_PUSH)]


def test_test_push_says_why_nothing_was_sent():
    assert W.test_push(PushStore([]), "a@b.org") == 1          # no phone registered
    s = PushStore(["t1"])
    assert W.test_push(s, "nobody@b.org") == 1 and s.sent == []  # no such account


# ----------------------------------------------------------------- messages
SECONDS = timedelta(seconds=1)


def message(role, minutes_ago=1, **extra):
    return {"senderId": "doc1" if role == "clinician" else "pat1", "senderRole": role, "senderName": "A. Nkeng",
            "text": "My pressure was 190 this morning", "timestamp": NOW - timedelta(minutes=minutes_ago), **extra}


def test_an_unread_message_is_notified_once_and_without_its_text():
    s, inbox = FakeStore(), W.Inbox()
    w = worker(s)
    inbox.apply([("pat1", "m1", message("clinician"))], NOW)
    assert w.messages(inbox, NOW + 5 * SECONDS) == {}                # an open conversation reads it first
    assert w.messages(inbox, NOW + 25 * SECONDS) == {"pushes": 1, "messages_notified": 1}
    assert s.pushed == [("pat1", "New message from your clinician")]
    assert s.push_options == [{"channel": "messages", "data": {"open": "messages", "patientId": "pat1"},
                               "tag": "messages-pat1"}]
    assert s.message_updates == [("pat1", "m1", {"notifiedAt": NOW})]
    # the listener brings the message back with notifiedAt, then with readAt: nothing more
    inbox.apply([("pat1", "m1", message("clinician", notifiedAt=NOW))], NOW + 30 * SECONDS)
    assert w.messages(inbox, NOW + timedelta(minutes=5)) == {} and len(s.pushed) == 1


def test_a_message_read_in_time_brings_no_notification():
    s, inbox = FakeStore(), W.Inbox()
    inbox.apply([("pat1", "m1", message("clinician"))], NOW)
    inbox.apply([("pat1", "m1", message("clinician", readAt=NOW + 3 * SECONDS))], NOW + 3 * SECONDS)
    assert worker(s).messages(inbox, NOW + timedelta(minutes=1)) == {} and s.pushed == []


def test_a_patients_messages_go_to_the_assigned_clinician_under_a_pseudonym():
    s, inbox = FakeStore(), W.Inbox()
    w = worker(s)
    inbox.apply([("pat1", "m1", message("patient", 3)), ("pat1", "m2", message("patient", 2))], NOW)
    w.messages(inbox, NOW + 30 * SECONDS)
    assert s.pushed == [("doc1", "2 new messages from P-PAT1")]
    # a third one while the first two are still unread: the count goes on, the same tag replaces it
    inbox.apply([("pat1", "m3", message("patient", 0))], NOW + timedelta(minutes=1))
    w.messages(inbox, NOW + timedelta(minutes=2))
    assert s.pushed[-1] == ("doc1", "3 new messages from P-PAT1")
    assert {o["tag"] for o in s.push_options} == {"messages-pat1"}
    assert not any("190" in b or "Nkeng" in b for _, b in s.pushed)


def test_notified_removed_and_old_messages_bring_nothing():
    s, inbox = FakeStore(), W.Inbox()
    inbox.apply([("pat1", "a", message("clinician", notifiedAt=NOW)),     # notified before a restart
                 ("pat1", "b", message("clinician")),
                 ("pat1", "c", message("clinician", 60 * 30))], NOW)       # beyond max_age_hours
    inbox.apply([("pat1", "b", None)], NOW)                                # removed
    assert worker(s).messages(inbox, NOW + timedelta(minutes=1)) == {} and s.pushed == []


def test_a_patient_without_a_clinician_is_marked_without_sending():
    s, inbox = FakeStore(), W.Inbox()
    del s.users["pat1"]["assignedClinicianId"]
    inbox.apply([("pat1", "m1", message("patient"))], NOW)
    assert worker(s).messages(inbox, NOW + timedelta(minutes=1)) == {"messages_notified": 1}
    assert s.pushed == [] and s.message_updates == [("pat1", "m1", {"notifiedAt": NOW})]


# ----------------------------------------------------------------- confirmation emails
class FakeMailer:
    from_address = "telemonitor.app@example.org"

    def __init__(self, failures=0):
        self.sent, self.failures = [], failures

    def send(self, to, subject, text, body):
        if self.failures:
            self.failures -= 1
            raise OSError("SMTP server unreachable")
        self.sent.append((to, subject, text, body))


def request(minutes_ago=0, **extra):
    return {"kind": "verify_email", "requestedAt": NOW - timedelta(minutes=minutes_ago), **extra}


def mail_worker(store, mailer):
    return W.Worker(store, load_thresholds(), {}, W.load_config(), mailer=mailer)


def test_a_request_brings_one_email_to_the_address_of_the_account():
    s, mailer, requests = FakeStore(), FakeMailer(), W.MailRequests()
    w = mail_worker(s, mailer)
    requests.apply([("pat1", request(email="someone.else@example.org"))])   # never the request's address
    assert w.emails(requests, NOW) == {"emails_sent": 1}
    to, subject, text, body = mailer.sent[0]
    assert to == "aline@example.org" and subject == M.SUBJECT
    assert text.startswith("Hello Aline,") and "oobCode=X1" in text and "oobCode=X1" in body
    assert s.mail_updates == [("pat1", {"sentAt": NOW, "outcome": "emails_sent"})]
    # the listener brings the request back with sentAt: nothing more; a new request later: a new email
    requests.apply([("pat1", request(sentAt=NOW))])
    assert w.emails(requests, NOW + timedelta(seconds=30)) == {} and len(mailer.sent) == 1
    requests.apply([("pat1", request(-2))])
    assert w.emails(requests, NOW + timedelta(minutes=2)) == {"emails_sent": 1} and len(mailer.sent) == 2


def test_confirmed_unknown_and_old_requests_send_nothing():
    s, mailer, requests = FakeStore(), FakeMailer(), W.MailRequests()
    s.accounts["pat2"] = ("b@example.org", True)
    s.accounts["pat3"] = ("c@example.org", False)
    requests.apply([("pat2", request()), ("gone", request()), ("pat3", request(60 * 48))])
    assert mail_worker(s, mailer).emails(requests, NOW) == {
        "emails_already_confirmed": 1, "emails_no_address": 1, "emails_expired": 1}
    assert mailer.sent == [] and len(s.mail_updates) == 3


def test_a_failed_email_is_tried_again_a_minute_later_then_given_up():
    s, mailer, requests = FakeStore(), FakeMailer(failures=5), W.MailRequests()
    w = mail_worker(s, mailer)
    requests.apply([("pat1", request())])
    assert w.emails(requests, NOW) == {"errors": 1}
    assert w.emails(requests, NOW + timedelta(seconds=10)) == {}            # not before a minute
    assert w.emails(requests, NOW + timedelta(seconds=61)) == {"errors": 1}
    assert w.emails(requests, NOW + timedelta(seconds=122)) == {"errors": 1}
    assert w.emails(requests, NOW + timedelta(seconds=300)) == {}           # three tries, then the app's button
    assert s.mail_updates == []
    mailer2, requests2 = FakeMailer(failures=1), W.MailRequests()
    w2 = mail_worker(FakeStore(), mailer2)
    requests2.apply([("pat1", request())])
    w2.emails(requests2, NOW)
    assert w2.emails(requests2, NOW + timedelta(seconds=61)) == {"emails_sent": 1}


def test_without_an_smtp_account_the_worker_sends_no_email():
    requests = W.MailRequests()
    requests.apply([("pat1", request())])
    assert worker(FakeStore()).emails(requests, NOW) == {}


def reset(minutes_ago=0, **extra):
    return {"requestedAt": NOW - timedelta(minutes=minutes_ago), **extra}


def test_a_reset_request_brings_the_link_to_the_accounts_own_address():
    s, mailer, resets = FakeStore(), FakeMailer(), W.MailRequests()
    resets.apply([("aline@example.org", reset())])
    assert mail_worker(s, mailer).resets(resets, NOW) == {"resets_sent": 1}
    to, subject, text, body = mailer.sent[0]
    assert to == "aline@example.org" and subject == M.RESET_SUBJECT
    assert text.startswith("Hello Aline,") and "mode=resetPassword&oobCode=R1" in text
    assert "Choose a new password" in body and "your password stays the same" in body
    assert s.reset_updates == [("aline@example.org", {"sentAt": NOW, "outcome": "resets_sent"})]


def test_a_reset_for_an_address_without_an_account_sends_nothing_and_leaves_no_trace():
    s, mailer, resets = FakeStore(), FakeMailer(), W.MailRequests()
    s.accounts["pat2"] = ("b@example.org", False)
    s.disabled.add("pat2")
    resets.apply([("nobody@example.org", reset()), ("b@example.org", reset()),
                  ("aline@example.org", reset(60 * 48))])
    assert mail_worker(s, mailer).resets(resets, NOW) == {
        "resets_no_account": 1, "resets_disabled": 1, "resets_expired": 1}
    assert mailer.sent == []
    assert ("nobody@example.org", None) in s.reset_updates                 # deleted, not marked


def test_resets_for_one_account_are_capped_per_day():
    s, mailer, resets = FakeStore(), FakeMailer(), W.MailRequests()
    w = mail_worker(s, mailer)
    cap = W.load_config()["password_resets_per_day"]
    for i in range(cap + 2):                                   # once a minute, as the rules allow
        t = NOW + timedelta(minutes=i)
        resets.apply([("aline@example.org", {"requestedAt": t})])
        w.resets(resets, t)
    assert len(mailer.sent) == cap and s.reset_updates[-1][1]["outcome"] == "resets_limited"
    later = NOW + timedelta(days=1, minutes=1)
    resets.apply([("aline@example.org", {"requestedAt": later})])
    assert w.resets(resets, later) == {"resets_sent": 1}                     # a day later: sent again


def test_the_email_escapes_the_name_and_carries_the_logo_inline():
    link = "https://telemonitor.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=Q"
    subject, text, body = M.verification_email('<script>alert(1)</script> Eve', link)
    assert "<script>" not in body and "&lt;script&gt;" in body
    assert 'href="https://telemonitor.firebaseapp.com/__/auth/action?mode=verifyEmail&amp;oobCode=Q"' in body
    assert M.verification_email(None, link)[1].startswith("Hello,\n")
    msg = M.message("aline@example.org", ("TeleMonitor", "telemonitor.app@example.org"), subject, text, body)
    assert msg["From"] == "TeleMonitor <telemonitor.app@example.org>"
    assert msg["Date"] and msg["Message-ID"].endswith("@example.org>")
    assert [p.get_content_type() for p in msg.walk()] == [
        "multipart/alternative", "text/plain", "multipart/related", "text/html", "image/png"]
    assert f"cid:{M.LOGO_CID}" in body
