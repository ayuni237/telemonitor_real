import os
from datetime import datetime, timedelta, timezone

import numpy as np

os.environ["TELEMONITOR_SERVE"] = "0"
from telemonitor.labels import load_thresholds
from telemonitor.serve import worker as W
from telemonitor.serve.artifact import Artifact

NOW = datetime(2026, 10, 20, 12, tzinfo=timezone.utc)


class FakeStore:
    def __init__(self):
        self.users = {"pat1": {"role": "patient", "assignedClinicianId": "doc1", "age": 61, "sex": "Female"},
                      "doc1": {"role": "clinician", "alternateClinicianId": "doc2"},
                      "doc2": {"role": "clinician"}}
        self.reads = {"pat1": {}}
        self.evs = {"pat1": {}}
        self.pushed = []

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

    def push(self, uid, title, body):
        self.pushed.append((uid, body))
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
