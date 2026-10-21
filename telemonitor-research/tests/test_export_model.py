import importlib.util
import json
import os
import sys
from pathlib import Path

import joblib
import pandas as pd
import pytest
import yaml

os.environ["TELEMONITOR_SERVE"] = "0"
from telemonitor.labels import load_thresholds
from telemonitor.models import tabular as T
from telemonitor.objective import load_cost
from telemonitor.serve import artifact

ROOT = Path(__file__).resolve().parents[1]


def load_script():
    sys.path.insert(0, str(ROOT / "scripts"))
    spec = importlib.util.spec_from_file_location("export11", ROOT / "scripts" / "11_export_model.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def fake_run(tmp: Path, version: str) -> Path:
    run = tmp / "runs" / "haemodynamic_0h_abc"
    (run / "config").mkdir(parents=True)
    (run / "external" / "models").mkdir(parents=True)
    (run / "manifest.json").write_text(json.dumps({"status": "complete", "inputs": {
        "task": "haemodynamic", "benchmark": {"feature_set": "primary"}}}))
    (run / "config" / "thresholds.yaml").write_text(yaml.safe_dump({"version": version}))
    (run / "config" / "cost.yaml").write_text(yaml.safe_dump(load_cost()))
    good = {"rps": 0.05, "auroc_alert": 0.85, "cal_intercept": 0.0, "cal_slope": 1.0, "brier_alert": 0.1,
            "net_benefit_0.1": 0.1, "net_benefit_0.2": 0.08, "net_benefit_0.3": 0.05}
    bad = {**good, "rps": 0.09, "auroc_alert": 0.7, "cal_intercept": 0.4, "net_benefit_0.2": 0.02}
    rows = [{"candidate": "catboost", "repeat": -1, "fold": -1, "kept": True, **good},
            {"candidate": "ordinal_logistic", "repeat": -1, "fold": -1, "kept": True, **bad},
            {"candidate": "ordinal_logistic", "repeat": 0, "fold": 0, "kept": True, **{**good, "rps": 0.01}}]
    pd.DataFrame(rows).to_csv(run / "trials.csv", index=False)
    for name in ("catboost", "ordinal_logistic"):
        joblib.dump(T.Prior().fit(None, [0, 1, 2, 3]), run / "external" / "models" / f"{name}.joblib")
        (run / "external" / "models" / f"{name}.params.json").write_text(json.dumps({"window": 48}))
    pd.DataFrame([{"candidate": "catboost", "rps": 0.06, "rps_lo": 0.05, "rps_hi": 0.07, "auroc_alert": 0.8}]) \
        .to_csv(run / "external" / "external.csv", index=False)
    return run


def test_the_lowest_cost_family_of_the_final_search_is_exported(tmp_path, monkeypatch):
    mod = load_script()
    monkeypatch.setattr(mod, "ARTIFACTS", tmp_path / "artifacts")
    run = fake_run(tmp_path, load_thresholds().version)
    out = mod.export(run)                       # outer-fold rows (repeat 0) are ignored
    a = artifact.load(out)
    assert a.manifest["candidate"] == "catboost" and a.manifest["window_hours"] == 48
    assert a.manifest["development"] == run.name and a.manifest["metrics"]["douala"]["rps"] == 0.06


def test_a_run_labelled_with_other_thresholds_is_refused(tmp_path, monkeypatch):
    mod = load_script()
    monkeypatch.setattr(mod, "ARTIFACTS", tmp_path / "artifacts")
    with pytest.raises(SystemExit, match="rerun the benchmark"):
        mod.export(fake_run(tmp_path, "1999-01-01"))
