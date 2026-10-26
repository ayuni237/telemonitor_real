"""Regenerate the parity fixtures of the Flutter app.

1. Research labels: the app mirrors configs/thresholds.yaml in
   lib/services/clinical_levels.dart (test/clinical_levels_parity_test.dart).
2. Home triage and verification profile: the app mirrors configs/home_protocol.yaml in
   lib/services/home_protocol.dart (test/home_protocol_parity_test.dart).
Each test compares the Dart results with those computed here, on every boundary of every
channel. Run this script after any change of either table, update the Dart mirror, then run
`flutter test` in telemonitor/.
Output: ../telemonitor/test/fixtures/levels_parity.json and home_parity.json
"""
import json

import numpy as np
import pandas as pd

import _common
from telemonitor.labels import MGDL_PER_MMOLL, load_thresholds

OUT = _common.ROOT.parent / "telemonitor" / "test" / "fixtures" / "levels_parity.json"
t = load_thresholds()


def levels(ch, xs):
    return [None if np.isnan(v) else int(v) for v in t.channel_level(ch, np.array(xs, float))]


def opt(x):
    return None if pd.isna(x) else x


sbp, dbp, hr = list(range(60, 261)), list(range(30, 161)), list(range(30, 221))
gl = [round(x, 2) for x in np.arange(0.30, 6.01, 0.01)]                 # g/L, as charted in Douala
glu = [g * 1000 / (10 * MGDL_PER_MMOLL) for g in gl] + [round(x, 1) for x in np.arange(1.0, 35.01, 0.1)]
rng = np.random.default_rng(0)
combos = pd.DataFrame({"sbp": rng.choice([np.nan, *range(70, 230)], 400),
                       "dbp": rng.choice([np.nan, *range(40, 140)], 400),
                       "hr": rng.choice([np.nan, *range(35, 160)], 400),
                       "glucose": rng.choice([np.nan, *np.arange(2.0, 25.0, 0.3)], 400)})
lab = t.label(combos)
fixture = {
    "version": t.version,
    "sbp": {"values": sbp, "levels": levels("sbp", sbp)},
    "dbp": {"values": dbp, "levels": levels("dbp", dbp)},
    "pulse": {"values": hr, "levels": levels("pulse", hr)},
    "glucose": {"values": glu, "levels": levels("glucose", glu)},
    "combined": [{"sbp": opt(r.sbp), "dbp": opt(r.dbp), "hr": opt(r.hr), "glucose": opt(r.glucose),
                  "haemodynamic": None if np.isnan(h) else int(h), "glycaemic": None if np.isnan(g) else int(g),
                  "overall": None if np.isnan(y) else int(y)}
                 for r, h, g, y in zip(combos.itertuples(), lab.y_haemodynamic, lab.y_glycaemic, lab.y)],
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(fixture), encoding="utf8")
print("written", OUT, "| threshold version", t.version)


# ---------------------------------------------------------------- home protocol (thesis ch.4 §triage)
from datetime import datetime, timedelta  # noqa: E402

from telemonitor.home_protocol import HomeReading, load_home_protocol  # noqa: E402

HOME_OUT = OUT.parent / "home_parity.json"
hp = load_home_protocol()
T0 = datetime(2026, 10, 1, 8)
contexts = ["Fasting", "Before meal", "After meal", "After medication", "After exercise", "Random", ""]
g_values = [round(x, 1) for x in np.arange(1.0, 35.01, 0.1)]


def home_cases():
    cases = []
    for i in range(500):
        r = HomeReading(time=T0, sbp=opt(combos.sbp.iat[i % 400]), dbp=opt(combos.dbp.iat[i % 400]),
                        hr=opt(combos.hr.iat[i % 400]),
                        glucose=None if i % 3 == 0 else round(float(rng.choice(g_values)), 1),
                        context=contexts[i % len(contexts)])
        if r.sbp is not None and r.dbp is None:
            r = HomeReading(r.time, r.sbp, r.sbp - 40, r.hr, r.glucose, r.context)
        cases.append({"sbp": r.sbp, "dbp": r.dbp, "hr": r.hr, "glucose": r.glucose, "context": r.context,
                      "haemodynamic": hp.haemodynamic_level(r), "glycaemic": hp.glycaemic_level(r),
                      "level": hp.level(r)})
    return cases


def profile_case(kind, readings, now_hours):
    rs = [HomeReading(time=T0 + timedelta(hours=h), **v) for h, v in readings]
    now = T0 + timedelta(hours=now_hours)
    p = hp.bp_profile(T0, rs, now) if kind == "bp" else hp.glucose_profile(T0, rs, now)
    keep = {k: v for k, v in p.items() if k not in ("start", "end", "profile")}
    return {"kind": kind, "input": [{"hours": h, **v} for h, v in readings], "now_hours": now_hours, **keep}


bp_on = [(12 + 12 * i, {"sbp": 128 + i % 3, "dbp": 80}) for i in range(14)]
bp_off = [(12 + 12 * i, {"sbp": 136 + i % 5, "dbp": 86}) for i in range(14)]
bp_low = [(12 + 12 * i, {"sbp": 104, "dbp": 66}) for i in range(14)]
bp_few = [(12 + 12 * i, {"sbp": 150, "dbp": 95}) for i in range(5)]
bp_one_day = [(1 + i, {"sbp": 150, "dbp": 95}) for i in range(8)]
glu_day = [(10, {"glucose": 6.0, "context": "Fasting"}), (12, {"glucose": 8.0, "context": "After meal"}),
           (14, {"glucose": 6.5, "context": "Before meal"}), (16, {"glucose": 9.0, "context": "After meal"}),
           (18, {"glucose": 6.8, "context": "Before meal"}), (20, {"glucose": 9.5, "context": "After meal"})]
glu_high = glu_day[:5] + [(20, {"glucose": 16.0, "context": "After meal"})]
profiles = [profile_case("bp", bp_on, 200), profile_case("bp", bp_off, 200), profile_case("bp", bp_low, 200),
            profile_case("bp", bp_on, 100), profile_case("bp", bp_on, 169), profile_case("bp", bp_few, 200),
            profile_case("bp", bp_one_day, 200), profile_case("glucose", glu_day, 21),
            profile_case("glucose", glu_high, 21), profile_case("glucose", glu_day[:4], 49),
            profile_case("glucose", glu_day[:4], 30)]

home = {
    "version": hp.version,
    "sbp": {"values": sbp, "levels": [hp.channel_level("sbp", v) for v in sbp]},
    "dbp": {"values": dbp, "levels": [hp.channel_level("dbp", v) for v in dbp]},
    "pulse": {"values": hr, "levels": [hp.channel_level("pulse", v) for v in hr]},
    "glucose_before_meal": {"values": g_values, "levels": [hp.channel_level("glucose_before_meal", v) for v in g_values]},
    "glucose_after_meal": {"values": g_values, "levels": [hp.channel_level("glucose_after_meal", v) for v in g_values]},
    "readings": home_cases(),
    "profiles": profiles,
}
HOME_OUT.write_text(json.dumps(home), encoding="utf8")
print("written", HOME_OUT, "| home protocol version", hp.version)
