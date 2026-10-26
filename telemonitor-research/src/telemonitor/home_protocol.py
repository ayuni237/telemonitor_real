"""Home triage and verification profile — thesis ch.4 §The self-measurement protocol and
three-level triage (Table "tab:thresholds", mihevc2025).

The research labels (labels.py) use in-hospital thresholds, the setting of the data. A home
deployment substitutes the out-of-office thresholds of the protocol (thesis ch.3
§Labelling): this module classifies a home reading green, yellow or red, and evaluates the
verification profile that a yellow reading starts (seven-day blood-pressure profile, one-day
six-point glucose profile). The table is versioned in configs/home_protocol.yaml; the
application mirrors it (lib/services/home_protocol.dart) and a parity fixture checks both
(scripts/07_app_parity_fixture.py).
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import yaml

from .labels import Rule, _OPS

DEFAULT_PROTOCOL = Path(__file__).resolve().parents[2] / "configs" / "home_protocol.yaml"
GREEN, YELLOW, RED = 0, 1, 2
CHANNELS = ("sbp", "dbp", "pulse", "glucose_before_meal", "glucose_after_meal")


@dataclass(frozen=True)
class HomeReading:
    """One home reading: measurement time, retained values, glucose context."""
    time: datetime
    sbp: float | None = None
    dbp: float | None = None
    hr: float | None = None
    glucose: float | None = None
    context: str = ""


@dataclass(frozen=True)
class HomeProtocol:
    version: str
    levels: tuple[str, ...]
    rules: dict[str, tuple[Rule, ...]]
    before_meal: frozenset[str]
    after_meal: frozenset[str]
    profiles: dict

    # ------------------------------------------------------------- one reading
    def channel_level(self, channel: str, value: float | None) -> int | None:
        if value is None:
            return None
        v = round(float(value), 6)
        level = GREEN
        for r in self.rules[channel]:
            if _OPS[r.op](v, r.value):
                level = max(level, r.level)
        return level

    def glucose_channel(self, context: str) -> str:
        """Threshold set of a glucose reading: before a meal only when the context says
        so; when the meal status is not known, the after-meal set applies."""
        return "glucose_before_meal" if context in self.before_meal else "glucose_after_meal"

    def levels_of(self, r: HomeReading) -> dict[str, int]:
        """Level of each measured channel."""
        out = {}
        for ch, v in (("sbp", r.sbp), ("dbp", r.dbp), ("pulse", r.hr)):
            lv = self.channel_level(ch, v)
            if lv is not None:
                out[ch] = lv
        if r.glucose is not None:
            out["glucose"] = self.channel_level(self.glucose_channel(r.context), r.glucose)
        return out

    def haemodynamic_level(self, r: HomeReading) -> int | None:
        lv = [v for k, v in self.levels_of(r).items() if k in ("sbp", "dbp", "pulse")]
        return max(lv) if lv else None

    def glycaemic_level(self, r: HomeReading) -> int | None:
        return self.levels_of(r).get("glucose")

    def level(self, r: HomeReading) -> int | None:
        """Level of the reading: the most severe of its channels; None when nothing is measured."""
        lv = list(self.levels_of(r).values())
        return max(lv) if lv else None

    def latest_level(self, readings: list[HomeReading], window: timedelta = timedelta(hours=96)) -> int | None:
        """Level of the last value of each channel within the window before the latest
        reading, each glucose judged in its own context (RiskAssessmentService.ruleLevel)."""
        if not readings:
            return None
        rs = sorted(readings, key=lambda r: r.time)
        cutoff = rs[-1].time - window
        sbp = dbp = hr = glucose = None
        context = ""
        for r in rs:
            if r.time <= cutoff:
                continue
            sbp = r.sbp if r.sbp is not None else sbp
            dbp = r.dbp if r.dbp is not None else dbp
            hr = r.hr if r.hr is not None else hr
            if r.glucose is not None:
                glucose, context = r.glucose, r.context
        return self.level(HomeReading(rs[-1].time, sbp, dbp, hr, glucose, context))

    # ------------------------------------------------------------- verification profile
    def _off_target(self, profile: str, means: dict[str, float | None]) -> bool:
        return any(means.get(c["channel"]) is not None and _OPS[c["op"]](means[c["channel"]], c["value"])
                   for c in self.profiles[profile]["off_target"])

    def bp_profile(self, start: datetime, readings: list[HomeReading], now: datetime) -> dict:
        """Seven-day blood-pressure profile started at `start` by a yellow reading; the
        triggering reading is not part of it (the profile is the readings that follow)."""
        p = self.profiles["bp_7d"]
        end = start + timedelta(hours=p["window_hours"])
        rs = [r for r in readings if start < r.time < end and r.time <= now and r.sbp is not None and r.dbp is not None]
        n, days = len(rs), len({r.time.date() for r in rs})
        out = {"profile": "bp_7d", "start": start, "end": end, "readings": n, "expected": p["expected_readings"],
               "days": days, "mean_sbp": None, "mean_dbp": None, "status": "in_progress", "off_target": None}
        if n:
            out["mean_sbp"] = round(sum(r.sbp for r in rs) / n, 1)
            out["mean_dbp"] = round(sum(r.dbp for r in rs) / n, 1)
        if now < end and n < p["expected_readings"]:
            return out
        if n < p["min_retained"] or days < p["min_days"]:
            out["status"] = "incomplete"
            return out
        out["status"] = "complete"
        out["off_target"] = self._off_target("bp_7d", {"sbp": out["mean_sbp"], "dbp": out["mean_dbp"]})
        return out

    def glucose_profile(self, start: datetime, readings: list[HomeReading], now: datetime) -> dict:
        """One-day six-point glucose profile started at `start` by a yellow reading."""
        p = self.profiles["glucose_6pt"]
        end = start + timedelta(hours=p["window_hours"])
        rs = [r for r in readings if start < r.time < end and r.time <= now and r.glucose is not None]
        before = [r.glucose for r in rs if r.context in self.before_meal]
        after = [r.glucose for r in rs if r.context not in self.before_meal]
        out = {"profile": "glucose_6pt", "start": start, "end": end, "readings": len(rs),
               "expected": p["expected_readings"], "before_meal": len(before), "after_meal": len(after),
               "mean_before_meal": round(sum(before) / len(before), 2) if before else None,
               "mean_after_meal": round(sum(after) / len(after), 2) if after else None,
               "status": "in_progress", "off_target": None}
        enough = len(before) >= p["min_before_meal"] and len(after) >= p["min_after_meal"]
        if now < end and not enough:
            return out
        if not enough:
            out["status"] = "incomplete"
            return out
        out["status"] = "complete"
        out["off_target"] = self._off_target("glucose_6pt", {"glucose_before_meal": out["mean_before_meal"],
                                                             "glucose_after_meal": out["mean_after_meal"]})
        return out


def load_home_protocol(path: str | Path = DEFAULT_PROTOCOL) -> HomeProtocol:
    cfg = yaml.safe_load(Path(path).read_text(encoding="utf8"))
    levels = tuple(cfg["levels"])
    rules, seen = {}, set()
    for ch in CHANNELS:
        rs = []
        for r in cfg["channels"][ch]:
            rule = Rule(r["id"], int(r["level"]), r["op"], float(r["value"]), r["source"])
            if rule.id in seen or rule.op not in _OPS or not 1 <= rule.level < len(levels) or not rule.source:
                raise ValueError(f"invalid home rule {rule.id!r}")
            seen.add(rule.id)
            rs.append(rule)
        rules[ch] = tuple(rs)
    ctx = cfg["context"]
    return HomeProtocol(str(cfg["version"]), levels, rules, frozenset(ctx["before_meal"]),
                        frozenset(ctx["after_meal"]), cfg["profiles"])
