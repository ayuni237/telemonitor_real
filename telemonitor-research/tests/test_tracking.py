import copy
import importlib.util
import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from telemonitor import search as S
from telemonitor import objective as O
from telemonitor.labels import load_thresholds
from telemonitor.run import external
from telemonitor.tracking import Run
from telemonitor.windows import make_samples

from test_models_sequence import cohort

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def setup(tmp_path_factory):
    df = cohort(n_patients=40, n_readings=8, seed=5)
    df["group"] = df["patient"]
    s = make_samples(df, load_thresholds())
    ext = make_samples(cohort(n_patients=12, n_readings=8, seed=9).assign(group=lambda d: d.patient), load_thresholds())
    sites = s.meta.patient.to_numpy() % 4
    bench = copy.deepcopy(S.load_bench())
    bench["validation"].update(outer_folds=2, inner_folds=2, repeats=1)
    bench["search"]["trials"] = {k: 2 for k in bench["search"]["trials"]}
    data = tmp_path_factory.mktemp("data") / "d.csv"
    df.to_csv(data, index=False)
    return s, ext, sites, bench, data, tmp_path_factory.mktemp("out")


def new_run(setup, cands):
    s, ext, sites, bench, data, out = setup
    return Run("haemodynamic", 0, cands, bench, O.load_cost(), ROOT / "configs" / "thresholds.yaml",
               {"data": data}, root=out)


def test_run_records_everything_and_resumes(setup):
    s, ext, sites, bench, data, out = setup
    cands = ["ordinal_logistic"]
    run = new_run(setup, cands)
    res = S.run(s, sites, load_thresholds(), "haemodynamic", cands, bench, recorder=run)
    ext_res = external(s, ext, load_thresholds(), "haemodynamic", cands, bench, O.load_cost(), recorder=run)
    run.finish({"ok": True})

    m = json.loads((run.dir / "manifest.json").read_text())
    assert m["status"] == "complete" and m["progress"]["folds_done"] == 2
    assert m["sessions"][0]["environment"]["python"] and (run.dir / "code").exists()
    for f in ("config/thresholds.yaml", "config/benchmark.yaml", "config/cost.yaml", "folds.csv", "trials.csv",
              "external/external.csv", "external/models/ordinal_logistic.joblib", "summary.json"):
        assert (run.dir / f).exists(), f
    trials = pd.read_csv(run.dir / "trials.csv")
    assert trials.groupby(["repeat", "fold"]).kept.sum().eq(1).all()         # one kept configuration per search
    z = np.load(run.dir / "predictions" / "outer" / "r0_f0" / "ordinal_logistic.npz")
    assert z["proba"].shape[1] == 4 and len(z["y"]) == len(z["sample"])
    assert set(ext_res.candidate) == {"prior", "persistence", "ordinal_logistic"}

    # identical inputs -> same folder, nothing recomputed, a second session logged
    again = new_run(setup, cands)
    assert again.dir == run.dir
    res2 = S.run(s, sites, load_thresholds(), "haemodynamic", cands, bench, recorder=again)
    pd.testing.assert_frame_equal(res.reset_index(drop=True), res2.reset_index(drop=True), check_dtype=False)
    assert len(json.loads((run.dir / "manifest.json").read_text())["sessions"]) == 2


def test_changed_configuration_starts_a_new_run(setup):
    a = new_run(setup, ["ordinal_logistic"])
    b = new_run(setup, ["ordinal_logistic", "forest"])
    assert a.dir != b.dir


def test_figures_are_redrawn_from_the_records(setup):
    s, ext, sites, bench, data, out = setup
    run = new_run(setup, ["ordinal_logistic"])
    if not (run.dir / "external" / "external.csv").exists():
        S.run(s, sites, load_thresholds(), "haemodynamic", ["ordinal_logistic"], bench, recorder=run)
        external(s, ext, load_thresholds(), "haemodynamic", ["ordinal_logistic"], bench, O.load_cost(), recorder=run)
    import sys
    sys.path.insert(0, str(ROOT / "scripts"))
    spec = importlib.util.spec_from_file_location("figs", ROOT / "scripts" / "08_figures.py")
    figs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(figs)
    figs.draw(run.dir)
    for name in ("outer_rps", "outer_auroc", "roc", "calibration", "decision_curves", "external_rps",
                 "external_decision_curves"):
        for ext_ in ("pdf", "png", "csv"):
            assert (run.dir / "figures" / f"{name}.{ext_}").exists(), name


def test_a_second_launch_of_a_running_run_is_refused(setup):
    import os
    from telemonitor.tracking import RunLocked
    run = new_run(setup, ["pca_logistic"])
    (run.dir / "run.lock").write_text(f"{os.getppid()} now")       # a live process that is not us
    with pytest.raises(RunLocked):
        new_run(setup, ["pca_logistic"])
    (run.dir / "run.lock").unlink()
    assert new_run(setup, ["pca_logistic"]).dir == run.dir             # free again once released
