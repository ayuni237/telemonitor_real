# SHAP analysis — results and how to use them

Run: `python3 run_shap.py`
Outputs land in `out/`.

---

## Why this replaces gain-based importance

Your supervisor wrote *"le poids des métriques n'est pas mesuré"*. It was
measured — but with **gain-based importance**, which has two documented
weaknesses that both apply to this data:

1. It is biased toward features offering more candidate split points.
2. It is unreliable when features are correlated, because correlated
   features share credit arbitrarily. Here `sbp` and `dbp` correlate at
   **r = 0.767** in the measured cohort.

SHAP values are derived from cooperative game theory and carry additivity
and consistency guarantees that gain does not.

---

## Result 1 — the two methods disagree substantially

| Feature | Gain rank | SHAP rank | Shift |
|---|---|---|---|
| `sbp_trend` | **16** | **7** | **+9** |
| `hr_std` | 15 | 8 | +7 |
| `glucose_last` | 8 | 15 | −7 |
| `glucose_std` | 7 | 12 | −5 |

**The headline finding, and the one to put in front of him:**

> Gain-based importance ranked `sbp_trend` **last of sixteen**. SHAP ranks
> it **seventh**.

This matters twice over. It justifies switching method — and it **defends
the trend descriptor he called arbitrary**. Under the measure he was
implicitly shown, trend looked worthless. Under the correct measure it is
mid-table and clearly contributing.

Figure: `out/fig_shap_vs_gain.png`

---

## Result 2 — the model learned the right *direction*, not just the right features

`out/fig_shap_critical.png` is the strongest single figure produced here.

For the CRITICAL class:

- **High** `sbp_mean` (red points) produces **positive** SHAP values —
  pushing the prediction toward critical.
- **Low** `sbp_mean` (blue points) produces **negative** SHAP values —
  pushing away from critical.
- The same holds for `dbp_mean`.

This is a stronger test of H2 than a ranking. A ranking says *which*
features the model uses; this says the model uses them **in the
physiologically correct direction**. A model that had latched onto an
artefact would show no such clean separation.

---

## Result 3 — cross-validated performance, unchanged

Patient-disjoint 5-fold (`GroupKFold`, patient as group):

| Metric | Value |
|---|---|
| Accuracy | 0.869 |
| Recall, critical | 0.587 |
| **Recall, high-or-critical** | **0.861** |
| **Precision, high-or-critical** | **0.869** |
| **Critical classified as stable or moderate** | **0** |

Reproduces the earlier calibration exactly.

---

## What to write in the thesis

Replace the gain-importance passage in Chapter 6 with:

> Feature attribution was computed using SHAP values (Lundberg & Lee,
> 2017) rather than gain-based importance. Gain is biased toward
> high-cardinality features and distributes credit arbitrarily among
> correlated predictors; systolic and diastolic pressure correlate at
> r = 0.767 in the measured cohort, making this a material concern.
>
> The two measures rank the leading features consistently — the channel
> means dominate under both — but diverge substantially for the
> dispersion and trend descriptors. Most notably, gain ranks
> `sbp_trend` last of sixteen features, whereas SHAP ranks it seventh.
> This divergence is consistent with gain's known behaviour under
> correlation, and indicates that the trend descriptor contributes more
> than a gain-based reading would suggest.
>
> Directional analysis of SHAP values for the critical class shows that
> elevated systolic and diastolic means produce positive attributions
> toward that class, and low values negative attributions. The model
> therefore uses these features in the physiologically expected
> direction, which supports H2 more substantively than a ranking alone.

Then keep the circularity caveat — it still applies on synthetic data.

---

## One reproducibility note worth recording

The generator draws patient covariates (age, sex, BMI) from a **separate
random stream** from the physiological values. Drawing them from the main
stream consumed random numbers and shifted every subsequent draw, changing
the cohort's label distribution from the calibrated 62.8/22.3/10.1/4.8 to
65.6/23.4/9.3/1.7 — a near-threefold reduction in the critical class,
caused purely by adding three variables that should have been independent.

This is the kind of defect that silently invalidates a comparison between
model variants. It is worth a sentence in the reproducibility appendix.

---

## Files

| File | Contents |
|---|---|
| `gen.py` | Calibrated generator, constants documented |
| `features.py` | The 16-feature construction |
| `train.py` | Model, weighting, cross-validation |
| `run_shap.py` | The analysis |
| `out/fig_shap_global.png` | Global importance |
| `out/fig_shap_vs_gain.png` | **The ranking comparison** |
| `out/fig_shap_per_class.png` | Which features drive each level |
| `out/fig_shap_critical.png` | **Direction of effect, critical class** |
| `out/shap_importance.csv` | Full table with both rankings |
| `out/shap_per_class.csv` | Per-class mean absolute SHAP |

Requires: `pip install shap xgboost scikit-learn matplotlib pandas`
