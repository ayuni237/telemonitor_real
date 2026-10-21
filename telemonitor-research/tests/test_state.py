import numpy as np
import pandas as pd

from telemonitor import state as S
from telemonitor.labels import load_thresholds
from telemonitor.windows import make_samples


def cohort(sbp_series, glucose=6.0, patient=1):
    """One reading per 12 h slot (morning, evening) for one patient."""
    rows = []
    for i, s in enumerate(sbp_series):
        rows.append({"patient": patient, "date": pd.Timestamp("2026-06-08") + pd.Timedelta(days=i // 2),
                     "time": "MS"[i % 2], "sbp": s, "dbp": s - 50, "hr": 80, "glucose": glucose})
    return pd.DataFrame(rows)


def st_of(cur, base, basesd=None, nbase=None):
    row = {}
    for j, c in enumerate(S.CHANNELS):
        row[f"cur_{c}"], row[f"base_{c}"] = cur[j], base[j]
        row[f"basesd_{c}"] = np.nan if basesd is None else basesd[j]
        row[f"nbase_{c}"] = 0 if nbase is None else nbase
    return pd.DataFrame([row])


def test_states_cut_current_and_baseline_windows():
    df = cohort([120, 122, 124, 126, 128, 130, 150, 160])       # 8 readings, 12 h apart
    s = make_samples(df, load_thresholds())
    st = S.states(s)
    k = len(s.meta) - 1                                          # anchor: reading 7 (t = 72 h)
    assert s.meta.anchor.iat[k] == 6
    # current (48, 72] -> readings at 60, 72 h ; baseline (-24, 48] -> readings 0..48 h
    assert st.loc[k, "cur_sbp"] == np.mean([130, 150])
    assert st.loc[k, "base_sbp"] == np.mean([120, 122, 124, 126, 128])
    assert st.loc[k, "nbase_sbp"] == 5


def test_cosine_is_blind_to_a_common_rise_and_distances_are_not():
    base = [120, 80, 70, 5.0]
    cur = [x * 1.5 for x in base]                                 # every channel up by half
    st = st_of(cur, base, basesd=[8, 6, 6, 0.8], nbase=6)
    sc = S.Scales(cohort_mean=np.array([130, 80, 75, 6.0]), cohort_sd=np.array([18, 11, 12, 2.0]),
                  within_sd=np.array([8, 6, 6, 0.8]), diff_cov=np.diag([64, 36, 36, 0.64]))
    assert abs(S.cosine_distance(st, sc)[0]) < 1e-12
    for name in ("euclidean_raw", "euclidean_cohort_z", "euclidean_patient_z", "mahalanobis"):
        assert S.MEASURES[name](st, sc)[0] > 1


def test_patient_scale_and_mahalanobis_agree_with_a_diagonal_covariance():
    st = st_of([140, 90, np.nan, 7.0], [130, 85, np.nan, 6.0], basesd=[10, 5, np.nan, 1.0], nbase=1_000_000)
    sc = S.Scales(within_sd=np.array([10, 5, 6, 1.0]), diff_cov=np.diag([100, 25, 36, 1.0]))
    # nbase large: the patient's own SD; changes 1, 1 and 1 SD on three shared channels
    assert np.isclose(S.euclidean_patient_z(st, sc)[0], np.sqrt(3))
    assert np.isclose(S.mahalanobis(st, sc)[0], np.sqrt(3))
    assert np.isclose(S.chebyshev_patient_z(st, sc)[0], 1.0)
    assert np.isclose(S.manhattan_patient_z(st, sc)[0], 3.0)


def test_correlated_change_counts_once_with_mahalanobis():
    # systolic and diastolic strongly correlated: a joint rise is less surprising
    cov = np.array([[100, 45, 0, 0], [45, 25, 0, 0], [0, 0, 36, 0], [0, 0, 0, 1.0]])
    sc = S.Scales(diff_cov=cov, within_sd=np.array([10, 5, 6, 1.0]))
    st = st_of([140, 90, np.nan, np.nan], [130, 85, np.nan, np.nan])
    assert S.mahalanobis(st, sc)[0] < S.euclidean_patient_z(st, sc)[0]


def test_too_few_shared_channels_give_nan():
    st = st_of([140, np.nan, np.nan, np.nan], [130, np.nan, np.nan, 6.0])
    sc = S.Scales()
    assert np.isnan(S.cosine_distance(st, sc, min_channels=2)[0])
    assert np.isfinite(S.euclidean_raw(st, sc, min_channels=1)[0])


def test_scales_fit_and_per_channel_report():
    df = pd.concat([cohort([120 + i for i in range(10)], patient=1), cohort([140 - i for i in range(10)], patient=2)])
    s = make_samples(df, load_thresholds())
    st = S.states(s)
    sc = S.Scales.fit(st)
    assert sc.cohort_sd.shape == (4,) and np.all(sc.within_sd[:2] > 0)
    rep = S.per_channel(st.iloc[-1], sc)
    assert set(rep) >= {"sbp", "dbp"} and rep["sbp"]["change"] < 0          # patient 2 is falling


def test_evolution_of_one_patient_for_the_service():
    t = [0, 12, 24, 36, 48, 60, 72]
    sbp = [130, 132, 128, 131, 129, 150, 154]
    sc = S.Scales(within_sd=np.array([5, 4, 6, 1.0]), diff_cov=np.diag([25, 16, 36, 1.0]))
    e = S.evolution(t, {"sbp": np.array(sbp, float), "dbp": np.array(sbp, float) - 50}, sc, "mahalanobis")
    assert e["channels"]["sbp"]["current"] == 152 and e["channels"]["sbp"]["baseline"] == 130
    assert e["channels"]["sbp"]["change_sd"] > 3 and e["distance"] > 3
    assert S.evolution(t, {"sbp": np.array(sbp, float)}, sc, None)["distance"] is None


def test_selection_prefers_the_simplest_candidate_within_the_best_interval():
    import importlib.util, sys
    from pathlib import Path
    root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(root / "scripts"))
    spec = importlib.util.spec_from_file_location("s12", root / "scripts" / "12_state_comparison.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    rows = [("cosine", 0.55, 0.50, 0.60), ("euclidean_raw", 0.70, 0.66, 0.74),
            ("euclidean_cohort_z", 0.72, 0.68, 0.76)] + \
           [(m, 0.60, 0.55, 0.65) for m in mod.CFG["candidates"][3:-1]] + [("mahalanobis", 0.73, 0.69, 0.77)]
    res = pd.DataFrame([{"data": "development", "outcome": mod.CFG["primary_outcome"], "measure": m,
                         "auroc": a, "lo": lo, "hi": hi} for m, a, lo, hi in rows])
    choice = mod.select(res)
    assert choice["best"] == "mahalanobis" and choice["selected"] == "euclidean_raw"
