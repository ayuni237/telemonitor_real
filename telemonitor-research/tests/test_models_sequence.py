import numpy as np
import pandas as pd
import pytest

from telemonitor.labels import load_thresholds
from telemonitor.metrics import rps
from telemonitor.models.sequence import SequenceModel, build_sequences
from telemonitor.models.tabular import Prior
from telemonitor.windows import make_samples


def cohort(n_patients=80, n_readings=10, seed=0):
    rng = np.random.default_rng(seed)
    frames = []
    for p in range(n_patients):
        start, slope = rng.uniform(110, 170), rng.normal(0, 4)
        sbp = start + slope * np.arange(n_readings) + rng.normal(0, 3, n_readings)
        glu = np.where(rng.random(n_readings) < 0.5, rng.uniform(5, 15, n_readings), np.nan)
        days = pd.to_datetime("2026-07-01") + pd.to_timedelta(np.arange(n_readings) // 2, unit="D")
        frames.append(pd.DataFrame({"patient": p, "date": days, "time": ["M", "S"] * (n_readings // 2),
                                    "sbp": sbp, "dbp": sbp - 55, "hr": 80.0, "glucose": glu,
                                    "age": rng.uniform(30, 80), "sex": rng.choice(["M", "F"])}))
    return pd.concat(frames, ignore_index=True)


@pytest.fixture(scope="module")
def data():
    s = make_samples(cohort(), load_thresholds())
    keep = s.meta.y_haemodynamic.notna().to_numpy()
    return s, keep


def test_sequences_are_left_padded_and_never_contain_the_target(data):
    s, _ = data
    X = build_sequences(s, L=48)
    assert X.values.shape[1:] == (5, 4)
    first = X.subset([0])
    assert first.steps[0, -1] == 1 and first.steps[0, 0] == 0            # left padding
    for k in (0, 3, len(s) - 1):
        assert X.values[k, -1, 0] == s.data.sbp.iat[s.meta.anchor.iat[k]]   # last step = anchor reading
    assert (X.gaps >= 0).all()


@pytest.mark.parametrize("kind", ["grud", "lstm"])
def test_sequence_models_beat_the_prior(data, kind):
    s, keep = data
    X = build_sequences(s, L=48).subset(np.flatnonzero(keep))
    y = s.meta.y_haemodynamic.to_numpy()[keep].astype(int)
    g = s.meta.group.to_numpy()[keep]
    values = s.meta[["v_sbp", "v_dbp", "v_hr", "v_glucose"]][keep].rename(columns=lambda c: c[2:])
    train = g < 60
    m = SequenceModel(kind=kind, hidden=8, max_epochs=80, aux_weight=0.5, seed=0)
    m.fit(X.subset(np.flatnonzero(train)), y[train], g[train], values[train])
    P = m.predict_proba(X.subset(np.flatnonzero(~train)))
    assert P.shape == ((~train).sum(), 4) and np.allclose(P.sum(1), 1)
    prior = Prior().fit(None, y[train]).predict_proba(np.zeros((~train).sum()))
    assert rps(P, y[~train]) < rps(prior, y[~train])
    assert m.n_parameters() < 5000
