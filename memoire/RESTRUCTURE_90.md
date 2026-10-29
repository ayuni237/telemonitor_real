# Thesis at 90 pages, on the model of Gwade's thesis

Model: *Multi-Task Transfer Learning and Application to Malaria Detection*, Gwade Steve,
MSc, NHPSD, 2025: 89 pages in all (13 front matter, 57 body, 8 references, 11 appendices).
Decisions of 27 October 2026:

1. **90 pages in total**, front matter, references and appendices included (supervisor).
2. **Structure of the sample** (unnumbered Introduction and Conclusion, four chapters, front
   matter). Its page design was replaced the same day at your request by a more modern one:
   Charter body (XCharter), Fira Sans headings and figures, navy and teal accents, chapter
   openings with a large number, bilingual title page, "Key points" box at each chapter end.
3. **Citations stay IEEE** (numbered, in order of citation), as the school plan asks.
4. Emphasis on **data collection, data treatment and the benchmarks**.
5. The results chapter reports **only our own results**; other studies' figures appear in
   the discussion only.
6. The ESP32 prototype was **not built**: it becomes a prospect.
7. Supervisor **Dr. Malong Yannick**, co-supervisor **Dr. Noulapeu Ngaffo**.
8. Defaults until you say otherwise: H2 (warning 24–48 h ahead) is reported as **not tested**
   unless you run it; the TRIPOD+AI checklist becomes a **one-page appendix**.

## 0. Status on 29 October 2026

Written and compiling without errors, undefined references or duplicate labels:
`memoire_restructure.pdf`, **83 pages** (`python parts/build.py`, then `pdflatex`, `biber`,
`pdflatex` ×2). The title is the registered one, as in the hospital's research authorisation
(*Design of a Telemonitoring System for Patients with Chronic Diseases (Hypertension,
Diabetes) Using Consultation Data, Home Measurements and Possibly Mobile Sensors*), and the
authorisation (No. 185/AR/MINSANTE/DHL/CM, 25 September 2026) is cited in §Ethics. The benchmark
runs are complete (`haemodynamic_0h_7472a36df1`, `glycaemic_0h_8cce0579ad`, 15 outer folds
each) and sections 4.2–4.4, the answers to RQ2–RQ4, the key points, the conclusion, the
Abstract and the Résumé are written from them.

Every number of chapter 4 comes from a script of `telemonitor-research`:

| Output | Script | Where |
|---|---|---|
| benchmark, selected family per fold, external validation | `13_results_tables.py` | `results/benchmark_*`, `selected_*`, `external_*` |
| lead time (H2), after the runs at 12 and 36 h | `13_results_tables.py` | `results/leads.tex` |
| subgroups, weight stability, importance, figure data | `15_results_details.py` | `results/subgroups_*`, `weights`, `importance_*`; `figures/data/` |
| deployed models | `11_export_model.py` | `artifacts/<task>/` (CatBoost, GRU-D) |
| state-evolution measures | `12_state_comparison.py` | `out/state_comparison.csv`; `configs/state_compare.yaml` |
| descriptive figures | `14_thesis_data_figures.py` | `figures/data/` (the per-reading Douala file is ignored by git) |

| Part | File | Pages now | Budget |
|---|---|---|---|
| Front matter (title, declaration, abstract, résumé, contents, acronyms, lists) | `00_front.tex` | 13 | 12 |
| Introduction | `01_introduction.tex` | 4 | 4 |
| Ch.1 Literature review | `02_review.tex` | 11 | 14 |
| Ch.2 Risk-tiering framework | `03_framework.tex` | 6 | 5 |
| Ch.3 Methodology and system | `04_methodology.tex` | 15 | 18 |
| Ch.4 Results and discussion | `05_results.tex` | 16 | 17 |
| Conclusion | `06_conclusion.tex` | 3 | 3 |
| References | (biblatex) | 5 | 7 |
| Appendices A–E | `07_appendices.tex` | 10 | 10 |

Still missing: the acknowledgments (after the Declaration) and, if you want them, the logos.
H2 (24 and 48 hours ahead) is reported as not tested until the runs at 12 and 36 h are made.

The old 125-page chapters (`parts/archive_125p/`) and the earlier versions `final_memoire` and
`correction memoir` are kept on the author's machine only, out of git; so is the French
working version (`memoire_fr`, `parts_fr/`, `results_fr/`). The preamble loads the
XCharter, Fira and newtx font maps itself, because MiKTeX had not registered them.

## 1. Structure and page budget

| Part (sample's equivalent) | Content | Pages |
|---|---|---|
| Front matter | title page, declaration, acknowledgments, abstract, résumé, contents, acronyms, lists of figures and tables | 12 |
| **Introduction** (unnumbered) | context; research problem and motivation; objectives and research questions; hypotheses H1–H4; contributions and outline | 4 |
| **Ch.1 Theoretical Foundations and Literature Review** | burden and care cascade; why one reading is not enough; home telemonitoring evidence (Mihevc, pooled effects, Cameroon); devices and IoT architectures (short); machine learning for clinical risk; observed gaps | 14 |
| **Ch.2 Risk-Tiering Framework** (the sample's "framework" chapter) | notation for an irregular patient series; the label from official thresholds; the forecasting task; rule floor final level = max(rule, model); three tiers and the home triage; state-evolution distance | 5 |
| **Ch.3 Methodology and System Implementation** | data sources and collection (Douala charts, eICU demonstration subset, harmonisation); curation and preprocessing (quality controls, outliers, windows, missing data); labelling; features; candidate models; experimental protocol (nested validation by hospital, search, selection cost); evaluation metrics; state-evolution protocol; the telemonitoring system (architecture, app, rules, worker); implementation details and reproducibility; ethics | 18 |
| **Ch.4 Results and Discussion** | data collection and treatment results; benchmark of risk models and external validation; state-evolution benchmark; system verification; discussion (answers to the research questions, comparison with the literature, implications, limitations) | 17 |
| **Conclusion** (unnumbered) | summary of contributions; principal findings; future directions | 3 |
| References (IEEE) | about 60 entries | 7 |
| Appendices | A. configurations and search spaces; B. full benchmark leaderboards; C. screens of the application; D. TRIPOD+AI (one page) | 10 |
| **Total** | | **90** |

The sample sets about 15 lines of prose per half page, with 11-point type and single
spacing; ours is 12-point with 1.5 spacing. The new design uses 11-point type, close to the
sample's, which alone saves about a fifth of the pages.

## 2. Where each current section goes

| Now | New place | Treatment |
|---|---|---|
| Ch.1 General introduction | Introduction | adapt to the sample's headings; hypotheses and contributions added |
| 2.1–2.2 Review introduction, conceptual framework | Ch.1 opening | half a page |
| 2.3.1 Global burden | 1.1 | 1.5 pages |
| 2.3.2 Sub-Saharan Africa, Cameroon | 1.2 | 2 pages; Bediang kept |
| 2.3.3 mHealth and clinical evidence | 1.3 | 2 pages; Mihevc kept |
| 4.2.2 "why a single measurement is not enough", follow-up frequency | 1.3 | 1 page |
| 2.3.4 Sensors and IoT | 1.4 | 1.5 pages; WHO position on devices |
| 4.1 Requirements (architectural, decision support) | 1.4 and 1.6 | the requirements table only |
| 2.3.5 Machine learning | 1.5 | 2 pages |
| 2.3.6–2.6 Privacy, comparison, limits, link, synthesis | 1.6 Observed gaps | 2 pages, with the synthesis table |
| 3.6.2 Labelling (the rule), 3.6.4d formulation, 3.6.5e risk score, 3.6.5f three levels, 4.2.2c home triage, 3.6.5g state evolution (definitions) | Ch.2 | the formal parts only |
| 3.2–3.5 Type, setting, collection, sampling | 3.1–3.2 | method kept; numbers obtained move to Ch.4 |
| 3.6.1 Preprocessing | 3.3 | kept, shorter |
| 3.6.3 Features | 3.4 | table of families, budget |
| 3.6.4 Candidates | 3.5 | candidates table |
| 3.6.5 Training, metrics, thresholds, state evolution (protocol) | 3.6–3.7 | kept, shorter |
| Ch.4 System (38 pages) | 3.8 | 4 pages: layers figure, data model, rules, worker, screens; implementation-status table |
| 3.6.6 Software tools | 3.9 | implementation details and reproducibility (the scripts) |
| 3.7 Ethics | 3.10 | 1 page |
| 3.8 Limitations, 4.7 limits | 4.5 Limitations | the limitation → consequence → response matrix |
| 4.1.2c Alert-volume arithmetic | 4.5 Discussion | half a page |
| 4.3.3–4.3.5 Latency, failure modes, security tables; 4.4 IoT prototype; 4.2.3 sensors; 4.2.2d collection procedure; 4.6.5 edge inference | removed | one sentence each where needed; ESP32 in future directions |
| Appendix A TRIPOD+AI | Appendix D | one page |

## 3. Results chapter (Ch.4): where each number comes from

| Section | Content | Source | Ready? |
|---|---|---|---|
| 4.1 Data collection and treatment | Douala cohort; quality controls; terminal digits; label distribution and uncertainty; old against sourced rule; eICU eligibility and harmonisation; samples per task; sample size against Riley; sensitivity analyses | scripts 01, 02, 04, 05, 09, 10 | yes |
| 4.2 Risk models | nested benchmark by hospital; comparison with persistence; selected family; subgroups; weight stability; importance | `06_benchmark.py`, `13_results_tables.py`, `15_results_details.py` | yes (15/15 folds per task) |
| 4.3 External validation on Douala | before and after intercept update | same | yes |
| 4.4 State evolution | eight measures, AUROC with intervals | `12_state_comparison.py` | yes |
| 4.5 System verification | parity tests, rules, offline behaviour, worker; assistant adversarial set | test suites; `integration_test/` | tests yes (171 Python, 48 Flutter); rules deployment and assistant **on a phone** pending |
| 4.6 Discussion | research questions, literature, implications, limitations | — | yes; H2 not tested |

Each results table will be produced by a script from the saved outputs (no number typed by
hand), as for the figures.

## 4. What you need to do

1. Read the thesis and tell me what to cut or change.
2. Send the acknowledgments, and the logos of the University of Douala and of NHPSD (PNG)
   if you want them on the title page (academic year 2025–2026 confirmed).
3. For H2 and RQ3: `powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\rerun_benchmarks.ps1 -Leads "12 36"`
   (about a day and a half), then `python scripts\13_results_tables.py`, which writes
   `results/leads.tex`; the lead-time paragraph, RQ3 and the key points are then written from it.
4. On a phone and in Firebase: deploy the Firestore rules, run the 22-question assistant set
   (§4.5 reports both as pending).
