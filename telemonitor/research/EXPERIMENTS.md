# Experiments answering the supervisor's review

Two criticisms are addressed empirically:

> *"choix des métriques arbitraire"*
> *"les variables du patient... elles entrent à quel niveau ?"*

**Read the methodological note first.** It is the most important part of
this document, and it changed the conclusions.

---

## Methodological note: why the first two answers were wrong

This analysis produced three successive conclusions, two of which did not
survive scrutiny.

**Round 1 — one cohort.** Mean-only appeared to produce 38 critical
windows classified as non-actionable, against 4 for a richer feature set.
A large, clear effect.

**Round 2 — five cohorts.** All 38 came from a single cohort. The other
four produced zero for every feature set. The effect was one unlucky
sample.

**Round 3 — fifteen cohorts.** Aggregate rates suggested the richer sets
were safer (0.60% versus 2.74%), and that a reduced 12-feature set was
safest of all. This looked like a finding and was nearly reported as one.

**Round 4 — thirty cohorts of 60 patients, paired comparison.** Both
conclusions collapsed:

| Comparison | Aggregate suggests | Paired test |
|---|---|---|
| 12 features vs 16 | 12 safer | **Reversed.** 16 = 34 errors, 12 = 47. Wilcoxon p = 0.328 |
| Mean-only vs 16 | 16 safer (2.67% vs 1.07%) | **Not significant.** Wilcoxon p = 0.631 |

The aggregate rates were driven by two cohorts out of thirty. In seed 28,
mean-only produced 36 errors against 2 for the full set; in seed 19, 22
against 0. Those two cohorts account for 58 of the 85 total errors.
Across the other 28, the sets are indistinguishable, and in four cohorts
mean-only was *better*.

**Round 5 — twenty cohorts of 120 patients, paired comparison.** The
comparison finally had enough critical windows to be informative, and a
clear result emerged (Experiment B below). The earlier inconclusive
finding was a power problem, not an absence of effect.

**The lesson, and it belongs in the thesis:**

> When the outcome class is rare and errors cluster within cohorts,
> aggregate error rates across pooled samples are misleading. Comparisons
> between model variants must be paired within cohort and tested
> accordingly. In this work, an apparent 2.5-fold difference in the rate
> of dangerous misclassification did not survive a paired signed-rank
> test, being attributable to two of thirty cohorts.

---

## Experiment A — do patient covariates help?

**Answer: no, and there is a principled reason.**

Two conditions were generated:

| Condition | Construction | corr(age, SBP) |
|---|---|---|
| Control | age, sex, BMI independent of physiology | −0.07 |
| Signal | age and BMI shift latent baseline BP (~0.55 mmHg/year, per population studies) | +0.26 |

The control exists to verify the design: if adding uninformative
covariates improved performance, the comparison would be measuring noise.

Result over 15 cohorts, covariates carrying a **real** effect:

| Feature set | Accuracy | Recall (actionable) |
|---|---|---|
| 16 descriptors | 0.879 ± 0.020 | 0.807 ± 0.155 |
| 16 + covariates | 0.877 ± 0.018 | 0.809 ± 0.157 |

No improvement, even when the covariates genuinely influence outcome.

### Why

The covariates act on the label *through* blood pressure. Age raises
baseline systolic pressure; the model already observes systolic pressure,
averaged over seven readings. Conditional on the window, the covariates
are d-separated from the label — they carry no additional information.

**For the thesis:**

> Patient covariates were evaluated as model inputs under a controlled
> design in which their influence on the outcome was explicitly
> constructed. No improvement was observed. This is consistent with the
> causal structure of the data-generating process: the covariates affect
> risk only through blood pressure, which the model observes directly, so
> they are conditionally independent of the label given the measurement
> window.

### Caveat

This holds where age acts *only* through blood pressure. In real patients
age and comorbidity may carry information not mediated by current
measurements — arterial stiffness, disease duration, end-organ damage.
Only clinical data can settle that, and the question remains open.

---

## Experiment B — are the four descriptors arbitrary?

**Answer: no. At adequate sample size the full descriptor set is
significantly better than the channel means alone, and the benefit lies
in precision rather than in recall.**

### Why the earlier runs were inconclusive

Cohorts of 60 patients were too small. The number of critical windows per
cohort varied by more than an order of magnitude between draws — one
cohort produced 20, another over 150 — so the comparison was dominated by
which patients happened to be generated, not by the feature set.

Doubling to **120 patients per cohort** stabilised it: critical windows
per cohort then ranged 123 to 308, and the effect became visible.

This was a power problem, not an absence of effect.

### Result: 20 cohorts x 120 patients = 2,400 simulated patients

3,976 critical windows in total. Paired comparison against the full set:

| Feature set | n | Accuracy | Precision (act.) | Recall (act.) | crit→low |
|---|---|---|---|---|---|
| mean only | 4 | 0.879 | 0.858 | 0.860 | 1.89% |
| mean + last | 8 | 0.887 | 0.869 | 0.861 | 1.86% |
| mean + trend + last | 12 | 0.889 | 0.875 | 0.861 | 1.71% |
| **all four (current)** | **16** | **0.892** | **0.878** | 0.860 | **1.63%** |

Wilcoxon signed-rank, paired within cohort, against the 16-feature set:

| Comparison | Accuracy | Precision |
|---|---|---|
| vs mean only (4) | **p = 0.0001** | **p = 0.0001** |
| vs mean + last (8) | **p = 0.0036** | **p = 0.0153** |
| vs 12 (no dispersion) | p = 0.097 | p = 0.053 |

### What this establishes

**The descriptors are not arbitrary.** The full set outperforms the
channel means alone on accuracy and precision at p = 0.0001, and the
improvement is monotonic as descriptors are added: 0.879 → 0.887 → 0.889
→ 0.892.

**The benefit is precision, not recall.** Recall on the actionable class
is statistically identical across every subset (~0.860). What the
additional descriptors buy is **fewer false alarms**: precision rises from
0.858 to 0.878. In a setting where clinician time is the scarce resource,
that is the practically relevant gain.

**The dispersion descriptors are marginal.** Removing the four `_std`
features costs 0.002 accuracy and 0.004 precision, at p = 0.097 and
p = 0.053 — suggestive but not conclusive. They are retained, but a
12-feature model would be defensible and is worth revisiting on clinical
data.

**Safety is unaffected.** The rate of critical windows assigned to
non-alerting levels does not differ significantly between subsets
(all p > 0.85). The earlier claim that the descriptors reduce this rate
is **not supported** and should not be made.

### For the thesis

> The descriptor set was evaluated by ablation over 20 independently
> generated cohorts of 120 patients each (2,400 simulated patients,
> 3,976 critical windows), with each subset evaluated on the same cohorts
> and compared by paired Wilcoxon signed-rank test.
>
> The complete descriptor set significantly outperforms the channel means
> alone on both accuracy (0.892 versus 0.879, p = 0.0001) and precision on
> the actionable class (0.878 versus 0.858, p = 0.0001), with performance
> improving monotonically as descriptors are added. Recall on the
> actionable class is statistically indistinguishable across subsets, as
> is the rate at which critical windows are assigned to non-alerting
> levels. The contribution of the dispersion, trend and endpoint
> descriptors is therefore to **reduce false alarms** rather than to
> increase detection — a relevant property where clinician attention is
> the constrained resource.
>
> An initial evaluation using cohorts of 60 patients was inconclusive.
> The number of critical windows per cohort varied by an order of
> magnitude at that size, and the resulting variance masked the effect.
> This is recorded as a power consideration for any replication.

---

## Files

| File | Contents |
|---|---|
| `experiment.py` | Single cohort — kept to document the pitfall |
| `experiment2.py` | 5 cohorts, both covariate conditions |
| `experiment3.py` | 15 cohorts |
| `verify_12.py` | **Paired 12 vs 16, 30 cohorts** |
| `verify_meanonly.py` | Paired mean-only vs 16, 30 cohorts of 60 |
| `verify_large.py` | **Paired ablation, 20 cohorts of 120 — the reportable result** |
| `out/verify_*.json` | Per-cohort raw results |

Reproduce with `python3 verify_large.py` (roughly ten minutes).
Requires `scipy` in addition to the earlier dependencies.
