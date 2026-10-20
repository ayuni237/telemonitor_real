"""Regenerate the parity fixture of the Flutter app's labelling rule.

The app mirrors configs/thresholds.yaml in lib/services/clinical_levels.dart;
its test (test/clinical_levels_parity_test.dart) compares the Dart levels with
the levels computed here, on every boundary of every channel. Run this script
after any change of the threshold table, update clinical_levels.dart, then run
`flutter test` in telemonitor/.
Output: ../telemonitor/test/fixtures/levels_parity.json
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
