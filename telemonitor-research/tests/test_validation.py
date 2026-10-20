import numpy as np
import pytest

from telemonitor import validation as V


def data(n_sites=20, per_site=30, seed=0):
    rng = np.random.default_rng(seed)
    sites = np.repeat(np.arange(n_sites), per_site)
    patients = sites * 10 + rng.integers(0, 5, len(sites))
    y = rng.random(len(sites)) < 0.25
    return y, sites, patients


def test_outer_folds_never_share_a_hospital_and_cover_everything():
    y, sites, _ = data()
    splits = list(V.outer_splits(y, sites, n_splits=5, repeats=2))
    assert len(splits) == 10
    for s in splits:
        assert not set(sites[s.train]) & set(sites[s.test])
        assert y[s.test].any()                                     # stratified: events in every test fold
    for r in (0, 1):
        tests = np.concatenate([s.test for s in splits if s.repeat == r])
        assert sorted(tests) == list(range(len(y)))


def test_repeats_change_the_assignment():
    y, sites, _ = data()
    a = [tuple(s.test) for s in V.outer_splits(y, sites, repeats=2) if s.repeat == 0]
    b = [tuple(s.test) for s in V.outer_splits(y, sites, repeats=2) if s.repeat == 1]
    assert set(a) != set(b)


def test_inner_folds_are_grouped_by_patient():
    y, _, patients = data()
    for tr, va in V.inner_splits(y, patients):
        assert not set(patients[tr]) & set(patients[va])


def test_corrected_ttest_is_more_conservative_than_naive():
    rng = np.random.default_rng(1)
    d = rng.normal(0.01, 0.02, 25)
    t_c, p_c = V.corrected_ttest(d, n_train=800, n_test=200)
    t_naive = d.mean() / (d.std(ddof=1) / np.sqrt(len(d)))
    assert abs(t_c) < abs(t_naive) and 0 < p_c < 1


def test_cluster_bootstrap_interval_contains_the_estimate():
    rng = np.random.default_rng(2)
    clusters = np.repeat(np.arange(30), 8)
    x = rng.normal(0, 1, 30)[clusters] + rng.normal(0, 0.1, len(clusters))
    est, lo, hi = V.cluster_bootstrap(lambda idx: x[idx].mean(), clusters, n_boot=500)
    assert lo < est < hi
    # resampling whole clusters gives a wider interval than resampling rows
    naive = np.percentile([x[rng.integers(0, len(x), len(x))].mean() for _ in range(500)], [2.5, 97.5])
    assert hi - lo > naive[1] - naive[0]
