import numpy as np
import pandas as pd
import pytest

from telemonitor import objective as O


def results():
    # three configurations: A dominates on every term, C is worst everywhere
    rows = {
        "A": dict(rps=0.10, auroc_alert=0.80, cal_intercept=0.0, cal_slope=1.0),
        "B": dict(rps=0.12, auroc_alert=0.75, cal_intercept=0.2, cal_slope=0.8),
        "C": dict(rps=0.15, auroc_alert=0.65, cal_intercept=0.5, cal_slope=0.5),
    }
    df = pd.DataFrame(rows).T
    for t, nb in ((0.1, (0.30, 0.25, 0.10)), (0.2, (0.25, 0.20, 0.05)), (0.3, (0.20, 0.15, 0.0))):
        df[f"net_benefit_{t:g}"] = nb
    return df


def test_config_weights_are_valid():
    cfg = O.load_cost()
    assert np.isclose(sum(t["weight"] for t in cfg["terms"].values()), 1.0)


def test_dominating_configuration_has_lowest_cost_and_is_stable():
    r = results()
    cost = O.selection_cost(r)
    assert cost.idxmin() == "A" and cost.idxmax() == "C"
    assert O.rank_stability(r)["A"] == pytest.approx(1.0)


def test_orientation_rewards_high_auroc_and_net_benefit():
    r = results()
    z = O.standardise(O.terms(r, O.load_cost()), O.load_cost())
    assert z.loc["A", "discrimination"] < z.loc["C", "discrimination"]
    assert z.loc["A", "utility"] < z.loc["C", "utility"]


def test_weights_can_change_the_winner():
    r = results()
    r.loc["B", "auroc_alert"] = 0.95                  # B now best on discrimination only
    disc_only = np.array([0.0, 1.0, 0.0, 0.0])
    assert O.selection_cost(r, weights=disc_only).idxmin() == "B"
    stab = O.rank_stability(r)
    assert 0 < stab["B"] < 1 and np.isclose(stab.sum(), 1.0)
