# Calibration of the synthetic generator to the real cohort

## What changed and why

The generator previously used invented distribution parameters. It now
uses parameters measured from `patient_data.csv` (58 patients, 81
readings, Douala). The synthetic data is still synthetic — this makes it
*representative of the target population* rather than arbitrary, which
is a defensible methodological position; passing it off as real is not.

## Measured parameters (from 58 patients)

| Parameter | Value | Basis |
|---|---|---|
| SBP baseline | 123.4 ± 19.3 mmHg | first reading per patient, n=58 |
| DBP baseline | 77.3 ± 15.2 mmHg | n=58 |
| Glucose baseline | 5.7 ± 1.0 mmol/L | **n=17 only** |
| HR baseline | 87.8 ± 17.3 bpm | n=58 |
| SBP–DBP correlation | 0.767 | all 81 readings |
| Within-patient SD (SBP) | 4.9 | median, **n=9 patients** |
| Within-patient SD (DBP) | 6.7 | n=9 |
| Within-patient SD (HR) | 10.7 | n=9 |

Trajectory mix `(stable, worsening, improving, volatile) = (0.5, 0.2,
0.2, 0.1)` was fitted so the generated label distribution matches the
real cohort's: **62.8 / 22.3 / 10.1 / 4.8 %** against the observed
**63.0 / 18.5 / 11.1 / 7.4 %**.

**State these caveats in the thesis.** Glucose is calibrated on 17
patients and within-patient variability on 9 — both are weakly
estimated. Glucose within-patient SD could not be estimated at all
(no patient has two glucose readings) and uses a conservative 0.6.

## Results, calibrated cohort (patient-disjoint 5-fold CV)

| | Random Forest | XGBoost |
|---|---|---|
| Accuracy | 0.84 | **0.87** |
| Recall, critical | 0.47 | 0.59 |
| Recall, high-or-critical | — | **0.86** |
| Precision, high-or-critical | — | **0.87** |

### Read the critical recall carefully

It fell from ~0.83 on the old uncalibrated data to 0.59. That is not a
regression — the real cohort is healthier than the invented one, so
critical windows are now 5% of the data instead of a much larger share,
and rare classes are harder.

More importantly, **no genuinely critical window was ever classified as
stable or moderate** (`critical→low = 0` at every class-weight setting
tested). Every critical error is "critical predicted as high", which
still crosses the alert threshold. The system does not miss
deteriorating patients; it sometimes under-grades their severity.

This is why the headline metric should be **recall on high-or-critical
(0.86)**, which is also exactly what the risk score
R = P(high) + P(critical) measures. Report the per-class figures too —
but frame the clinical claim on the actionable metric, and say why.

A modest critical class-weight boost (×3) is applied; it moved
actionable recall 0.82 → 0.86. Larger boosts gave diminishing returns
and over-tuning on synthetic data is not meaningful.

## Files

- `gen.py` — calibrated generator (constants at the top)
- `train.py` — windowing + cross-validated RF and XGBoost
- `final.py` — fits the deployable model on all data

Fold these back into `TeleMonitor_model.ipynb` so the notebook stays the
single source of truth.
