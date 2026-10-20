import copy

import numpy as np
import pandas as pd
import pytest

from telemonitor import search as S
from telemonitor.labels import load_thresholds
from telemonitor.windows import make_samples

from test_models_sequence import cohort


@pytest.fixture(scope="module")
def setup():
    df = cohort(n_patients=60, n_readings=10, seed=3)
    df["group"] = df["patient"]
    s = make_samples(df, load_thresholds())
    sites = (s.meta.patient.to_numpy() % 6)          # six "hospitals"
    bench = copy.deepcopy(S.load_bench())
    bench["validation"].update(outer_folds=3, inner_folds=2, repeats=1)
    bench["search"]["trials"] = {k: 2 for k in bench["search"]["trials"]}
    return s, sites, bench


def test_nested_benchmark_end_to_end(setup):
    s, sites, bench = setup
    cands = ["ordinal_logistic", "catboost", "value_ridge", "grud"]
    res = S.run(s, sites, load_thresholds(), "haemodynamic", cands, bench)
    per_fold = res.groupby(["repeat", "fold"]).candidate.apply(set)
    for got in per_fold:
        assert {"prior", "persistence", "selected", *cands} == got
    assert res[res.candidate.isin(cands)].n_trials.eq(2).all()
    assert np.isfinite(res.rps).all()
    # informed models beat the prior on average
    mean = res.groupby("candidate").rps.mean()
    assert mean["persistence"] < mean["prior"]
    c = S.compare(res, "ordinal_logistic", "prior")
    assert c["k"] == 3 and 0 <= c["p"] <= 1


def test_outer_folds_are_grouped_by_site(setup):
    s, sites, bench = setup
    from telemonitor import validation as V
    rows = np.flatnonzero(s.meta.y_haemodynamic.notna())
    ev = (s.meta.y_haemodynamic.to_numpy()[rows] >= 2).astype(int)
    for sp in V.outer_splits(ev, sites[rows], 3, 1, 0):
        assert not set(sites[rows][sp.train]) & set(sites[rows][sp.test])


def test_resume_keeps_completed_folds(setup, tmp_path):
    s, sites, bench = setup
    out = tmp_path / "bench.csv"
    first = S.run(s, sites, load_thresholds(), "haemodynamic", ["ordinal_logistic"], bench, out=out)
    import time
    t0 = time.time()
    again = S.run(s, sites, load_thresholds(), "haemodynamic", ["ordinal_logistic"], bench, out=out)
    assert time.time() - t0 < 5                       # nothing refitted
    pd.testing.assert_frame_equal(first.reset_index(drop=True), again.reset_index(drop=True), check_dtype=False)
