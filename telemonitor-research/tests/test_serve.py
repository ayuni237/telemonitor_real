import os
from datetime import datetime, timedelta

import numpy as np
import pytest

os.environ["TELEMONITOR_SERVE"] = "0"                 # do not build the module-level app on import
from fastapi.testclient import TestClient

from telemonitor.labels import load_thresholds
from telemonitor.models import tabular as T
from telemonitor.serve import app as A
from telemonitor.serve import artifact
from test_models_tabular import synthetic


@pytest.fixture(scope="module")
def client(tmp_path_factory):
    folder = tmp_path_factory.mktemp("artifacts")
    X, y, g, v = synthetic()
    X = X[["sbp_last", "dbp_last", "hr_last"]].assign(sbp_slope=0.0, glucose_last=np.nan, glucose_slope=np.nan,
                                                       glucose_n=0.0, age=60.0)
    from telemonitor import features as F
    X = X[F.PRIMARY]
    model = T.OrdinalLogistic(C=10.0).fit(X, y)
    artifact.save(model, folder / "haemodynamic", task="haemodynamic", candidate="ordinal_logistic",
                  window=48, feature_set="primary", threshold_version=load_thresholds().version)
    return TestClient(A.create_app(folder))


def readings(sbp_values, start=datetime(2026, 7, 1, 8)):
    return [{"time": (start + timedelta(hours=12 * i)).isoformat(), "sbp": s, "dbp": s - 50, "hr": 80}
            for i, s in enumerate(sbp_values)]


def test_health_lists_models_and_threshold_version(client):
    h = client.get("/health").json()
    assert h["status"] == "ok" and "haemodynamic" in h["models"] and h["threshold_version"] == "2026-10-19"


def test_low_pressure_gives_green_high_pressure_gives_red(client):
    low = client.post("/v1/risk", json={"readings": readings([118, 120, 119]), "age": 60, "sex": "F"}).json()
    high = client.post("/v1/risk", json={"readings": readings([182, 185, 190]), "age": 60, "sex": "F"}).json()
    assert low["tier"] == "green"
    assert high["rule"]["tier"] == "red" and high["tier"] == "red"
    assert high["conditions"]["haemodynamic"]["alert_probability"] > low["conditions"]["haemodynamic"]["alert_probability"]


def test_rule_floor_is_never_lowered(client):
    # SBP <= 90 is critical by the rule whatever the model says
    r = client.post("/v1/risk", json={"readings": readings([120, 118, 88])}).json()
    assert r["rule"]["level"] == 3 and r["tier"] == "red"


def test_impossible_values_are_ignored_and_empty_input_rejected(client):
    r = client.post("/v1/risk", json={"readings": [{"time": "2026-07-01T08:00:00", "sbp": 400, "dbp": 20}]})
    assert r.status_code == 422


def test_artifact_hash_is_checked(tmp_path):
    a = artifact.save(T.Prior().fit(None, [0, 1, 2, 3]), tmp_path / "x", task="haemodynamic", candidate="prior",
                      window=24, feature_set="primary", threshold_version="v")
    (tmp_path / "x" / "model.joblib").write_bytes(b"tampered")
    with pytest.raises(ValueError):
        artifact.load(tmp_path / "x")
