import re
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from telemonitor.home_protocol import GREEN, RED, YELLOW, HomeReading, load_home_protocol

ROOT = Path(__file__).resolve().parents[1]
BIB = ROOT.parent / "memoire" / "references.bib"
T0 = datetime(2026, 10, 1, 8)


@pytest.fixture(scope="module")
def hp():
    return load_home_protocol()


def at(hours, **kw):
    return HomeReading(time=T0 + timedelta(hours=hours), **kw)


@pytest.mark.parametrize("sbp,level", [(109, RED), (110, GREEN), (134, GREEN), (135, YELLOW), (174, YELLOW),
                                       (175, RED)])
def test_systolic_boundaries_of_the_protocol(hp, sbp, level):
    assert hp.channel_level("sbp", sbp) == level


@pytest.mark.parametrize("dbp,level", [(59, RED), (60, GREEN), (84, GREEN), (85, YELLOW), (104, YELLOW),
                                       (105, RED)])
def test_diastolic_boundaries_of_the_protocol(hp, dbp, level):
    assert hp.channel_level("dbp", dbp) == level


@pytest.mark.parametrize("context,glucose,level", [
    ("Fasting", 3.9, RED), ("Fasting", 4.0, GREEN), ("Fasting", 7.0, GREEN), ("Fasting", 7.1, YELLOW),
    ("Fasting", 10.0, YELLOW), ("Fasting", 10.1, RED), ("Before meal", 7.1, YELLOW),
    ("After meal", 3.9, RED), ("After meal", 5.5, GREEN), ("After meal", 10.0, GREEN),
    ("After meal", 10.1, YELLOW), ("After meal", 14.0, YELLOW), ("After meal", 14.1, RED),
    ("Random", 12.0, YELLOW), ("After exercise", 3.5, RED), ("", 9.0, GREEN)])
def test_glucose_threshold_depends_on_the_meal(hp, context, glucose, level):
    assert hp.level(at(0, glucose=glucose, context=context)) == level


def test_worst_channel_governs_and_nothing_measured_is_none(hp):
    assert hp.level(at(0, sbp=128, dbp=88)) == YELLOW               # diastolic yellow, systolic green
    assert hp.level(at(0, sbp=150, dbp=80, hr=135)) == RED            # pulse at the NEWS2 red score
    assert hp.level(at(0, sbp=125, dbp=80, glucose=11.0, context="Fasting")) == RED
    assert hp.haemodynamic_level(at(0, glucose=6.0, context="Fasting")) is None
    assert hp.level(at(0)) is None


def test_every_source_is_in_the_thesis_bibliography(hp):
    keys = set(re.findall(r"^@\w+\{([^,]+),", BIB.read_text(encoding="utf8"), flags=re.M))
    sources = {r.source for rs in hp.rules.values() for r in rs} | {hp.profiles["bp_7d"]["source"]}
    assert sources <= keys, f"missing from references.bib: {sorted(sources - keys)}"


def bp_series(values, start_hours=12, step=12):
    return [at(start_hours + step * i, sbp=s, dbp=d) for i, (s, d) in enumerate(values)]


def test_bp_profile_on_and_off_target(hp):
    on = bp_series([(128, 80)] * 14)
    p = hp.bp_profile(T0, on, now=T0 + timedelta(days=8))
    assert p["status"] == "complete" and p["readings"] == 14 and p["off_target"] is False
    off = bp_series([(140, 88)] * 14)
    assert hp.bp_profile(T0, off, now=T0 + timedelta(days=8))["off_target"] is True
    low = bp_series([(105, 65)] * 14)
    assert hp.bp_profile(T0, low, now=T0 + timedelta(days=8))["off_target"] is True


def test_bp_profile_completes_early_with_all_readings_and_is_incomplete_when_too_few(hp):
    full = bp_series([(128, 80)] * 14)
    assert hp.bp_profile(T0, full, now=T0 + timedelta(days=6))["status"] == "in_progress"   # 14th not yet in
    assert hp.bp_profile(T0, full, now=T0 + timedelta(days=7, hours=1))["status"] == "complete"
    few = bp_series([(150, 95)] * 5)                     # 5 retained readings: below the minimum of 6
    p = hp.bp_profile(T0, few, now=T0 + timedelta(days=8))
    assert p["status"] == "incomplete" and p["off_target"] is None
    one_day = [at(1 + i, sbp=150, dbp=95) for i in range(8)]          # 8 readings, one day
    assert hp.bp_profile(T0, one_day, now=T0 + timedelta(days=8))["status"] == "incomplete"


def test_the_triggering_reading_is_not_part_of_the_profile(hp):
    rs = [at(0, sbp=170, dbp=100)] + bp_series([(128, 80)] * 14)
    p = hp.bp_profile(T0, rs, now=T0 + timedelta(days=8))
    assert p["readings"] == 14 and p["mean_sbp"] == 128


def test_glucose_profile(hp):
    day = [at(10, glucose=6.0, context="Fasting"), at(12, glucose=8.0, context="After meal"),
           at(14, glucose=6.5, context="Before meal"), at(16, glucose=9.0, context="After meal"),
           at(18, glucose=6.8, context="Before meal"), at(20, glucose=9.5, context="After meal")]
    p = hp.glucose_profile(T0, day, now=T0 + timedelta(hours=21))
    assert p["status"] == "complete" and p["off_target"] is False
    high = day[:5] + [at(20, glucose=16.0, context="After meal")]
    assert hp.glucose_profile(T0, high, now=T0 + timedelta(hours=21))["off_target"] is True     # mean after 11
    assert hp.glucose_profile(T0, day[:4], now=T0 + timedelta(hours=49))["status"] == "incomplete"


def test_latest_level_uses_the_last_value_of_each_channel_within_four_days(hp):
    rs = [at(0, glucose=2.5, context="Fasting"),                     # older than 96 h before the last: ignored
          at(100, sbp=120, dbp=80, hr=80), at(112, sbp=125, dbp=82)]
    assert hp.latest_level(rs) == GREEN
    assert hp.latest_level(rs + [at(120, glucose=8.0, context="Fasting")]) == YELLOW
    assert hp.latest_level(rs + [at(120, glucose=8.0, context="After meal")]) == GREEN
    assert hp.latest_level([]) is None
