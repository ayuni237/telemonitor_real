import numpy as np
import pytest

from telemonitor import sample_size as S


def test_reference_example_of_pmsampsize():
    # pmsampsize(type="b", csrsquared=0.288, parameters=24, prevalence=0.174):
    # criteria 623 / 662 / 221, minimum n = 662 (115 events, 4.8 per parameter)
    r = S.riley_binary(0.288, 24, 0.174)
    assert (r["n1_shrinkage"], r["n2_r2_difference"], r["n3_overall_risk"]) == (623, 662, 221)
    assert r["n_required"] == 662


def test_cstat_conversion_is_monotone_and_bounded():
    r = [S.cstat_to_r2cs(c, 0.3, n=200_000) for c in (0.6, 0.7, 0.8)]
    assert 0 < r[0] < r[1] < r[2] < S.max_r2cs(10_000, 0.3)
    assert S.cstat_to_r2cs(0.7, 0.3, n=200_000) == pytest.approx(S.cstat_to_r2cs(0.7, 0.7, n=200_000), abs=0.01)


def test_max_parameters_inverts_the_criteria():
    r2, prev = 0.1, 0.4
    p = S.max_parameters(500, r2, prev)
    need = lambda k: max(S.riley_binary(r2, k, prev)[c] for c in ("n1_shrinkage", "n2_r2_difference"))
    assert need(p) <= 500 < need(p + 1)


def test_icc_and_design_effect():
    groups = np.repeat(np.arange(20), 10)
    y_same = np.repeat(np.arange(20) % 2, 10)           # outcome constant within clusters
    assert S.icc_oneway(y_same, groups) == pytest.approx(1.0)
    deff, n_eff = S.effective_n(groups, 1.0)
    assert deff == pytest.approx(10) and n_eff == pytest.approx(20)
    assert S.effective_n(groups, 0.0) == (1.0, 200.0)
