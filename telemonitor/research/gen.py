"""Calibrated synthetic cohort generator.

Distribution parameters measured from the real Cameroonian cohort
(patient_data.csv, n=58 patients, 81 measurement events).
"""
import numpy as np, pandas as pd

# ---- Calibration constants, measured from the real cohort ----------
SBP_MEAN, SBP_SD = 123.4, 19.3      # n=58
DBP_MEAN, DBP_SD = 77.3, 15.2       # n=58
GLU_MEAN, GLU_SD = 5.7, 1.0         # n=17 only  -> weakly estimated
HR_MEAN,  HR_SD  = 87.8, 17.3       # n=58
R_SBP_DBP = 0.767                   # all 81 readings
W_SBP, W_DBP, W_HR = 4.9, 6.7, 10.7 # within-patient SD, n=9 patients
W_GLU = 0.6                         # not estimable; conservative

# Trajectory mix fitted so the generated label distribution matches the
# real cohort's (63.0 / 18.5 / 11.1 / 7.4 %).
P_TRAJ = (0.5, 0.2, 0.2, 0.1)

LEVELS = ["stable", "moderate", "high", "critical"]

def risk_from_values(sbp, dbp, glu):
    """ESH 2023 thresholds. Most severe channel wins."""
    if sbp >= 180 or dbp >= 110 or glu >= 14: return 3
    if sbp >= 160 or dbp >= 100 or glu >= 11: return 2
    if sbp >= 140 or dbp >= 90  or glu >= 8:  return 1
    return 0

# Age effect on systolic pressure. Population studies report a rise of
# roughly 0.5 mmHg per year of adult age; BMI is also positively
# associated with blood pressure. These are used ONLY in the
# `covariate_effect=True` condition, to create a cohort in which the
# covariates genuinely carry label information.
AGE_REF, AGE_SLOPE_SBP = 52.0, 0.55
BMI_REF, BMI_SLOPE_SBP = 26.5, 0.45


def generate(n_patients=60, days=45, seed=42, p_traj=P_TRAJ,
             with_covariates=False, covariate_effect=False):
    RNG = np.random.default_rng(seed)
    CRNG = np.random.default_rng(seed + 1000)   # covariates only
    rows = []
    for pid in range(n_patients):
        # sbp and dbp drawn jointly to preserve the measured correlation
        z1, z2 = RNG.normal(size=2)
        base_sbp = SBP_MEAN + SBP_SD * z1
        base_dbp = DBP_MEAN + DBP_SD * (R_SBP_DBP*z1 + np.sqrt(1-R_SBP_DBP**2)*z2)
        base_glu = RNG.normal(GLU_MEAN, GLU_SD)
        base_hr  = RNG.normal(HR_MEAN, HR_SD)

        # Covariates are drawn from a SEPARATE stream. Drawing them from
        # RNG would consume values and shift every subsequent draw,
        # silently changing the cohort relative to the calibrated
        # baseline — the 16-feature and 19-feature experiments would then
        # not be comparable.
        age = int(np.clip(CRNG.normal(52, 14), 20, 90))
        sex = int(CRNG.integers(0, 2))
        bmi = float(np.clip(CRNG.normal(26.5, 4.5), 16, 45))

        if covariate_effect:
            # Shift the LATENT baseline, so the label distribution moves
            # with it and the covariates genuinely predict outcome.
            shift = (AGE_SLOPE_SBP * (age - AGE_REF)
                     + BMI_SLOPE_SBP * (bmi - BMI_REF))
            base_sbp += shift
            base_dbp += 0.45 * shift

        traj = RNG.choice(["stable","worsening","improving","volatile"], p=p_traj)
        s_sbp = {"stable":0,"worsening":1.1,"improving":-0.8,"volatile":0}[traj]
        s_glu = {"stable":0,"worsening":0.09,"improving":-0.06,"volatile":0}[traj]
        vol = 2.0 if traj == "volatile" else 1.0

        for d in range(days):
            # latent physiological state
            lat_sbp = base_sbp + s_sbp*d + RNG.normal(0, 2)
            lat_dbp = base_dbp + 0.5*s_sbp*d + RNG.normal(0, 1.5)
            lat_glu = base_glu + s_glu*d + RNG.normal(0, 0.3)
            # label comes from the LATENT state
            label = risk_from_values(lat_sbp, lat_dbp, lat_glu)
            # the model observes the latent state plus measurement noise,
            # so the labelling rule cannot simply be inverted
            row = dict(
                patient=pid, day=d,
                sbp=lat_sbp + RNG.normal(0, W_SBP*vol),
                dbp=lat_dbp + RNG.normal(0, W_DBP*vol),
                glucose=lat_glu + RNG.normal(0, W_GLU),
                hr=base_hr + RNG.normal(0, W_HR) + 0.05*(lat_sbp - SBP_MEAN),
                label=label)
            if with_covariates:
                row.update(age=age, sex=sex, bmi=bmi)
            rows.append(row)
    return pd.DataFrame(rows)
