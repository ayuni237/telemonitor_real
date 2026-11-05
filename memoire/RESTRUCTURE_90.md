# Thesis plan and status, on the model of Gwade's thesis

(The file keeps the name of the 90-page plan of 27 October; the cap was lifted on 3 November.)

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

## 0. Status on 5 November 2026

**Revision of 5 November 2026, at the author's request: symbols and links.** No change of method
or result:

- Every displayed formula is followed by a "where …" sentence that names each of its symbols
  (16 formulas). The main measures, which had no formula, now have one: RPS, Brier score and net
  benefit, and the logistic recalibration that defines the calibration intercept and slope
  (ch.3 §Evaluation Metrics). The GRU-D decay is written as the code computes it (a decay learned
  from the gaps of all channels, `models/sequence.py`), not as a single rate per channel.
- One description corrected: ch.2 said that the classification uses an ordinal loss. That holds
  for the proportional-odds model and the deep temporal models; CatBoost and the random forest are
  fitted with the standard multi-class loss, and the order of the levels reaches them through the
  RPS that drives their search and the choice among families.
- Links: the citation numbers [n], the DOIs and the web addresses are blue and clickable; each
  reference ends with the pages that cite it ("cit. on pp."), as links back to the text.
  Cross-references and the contents stay black but are links too.
- Bibliography: DOI or address added for the WHO 2021 guideline, the HEARTS package, Kingue et al.
  (with its full author list), Van Calster et al., the two ISO standards and Bergstra et al., and
  the reprint of Mahalanobis (1936); each checked against Crossref or the publisher's page. Still
  without a link: the two Cameroonian laws (no official online text found) and the books of
  Iglewicz and Kish.

Compiles without errors, undefined references or overfull boxes: **115 pages**.

**Revision of 4 November 2026: rigour audit** (checklist in `telemonitor-research/RESEARCH_PLAN.md`
§7, decisions left to you in §6e). Four corrections, no change of method:

- The intercept update on Douala is now scored with each patient's intercept fitted on the other
  patients: Brier score 0.148 → 0.146 for CatBoost and 0.237 → 0.223 for GRU-D (0.142 and 0.221
  when fitted and scored on the same patients), net benefit 0.084 (ch.3 §external validation,
  ch.4 Calibration and Clinical utility; I48).
- H3 is read as "not rejected; equivalence not shown" instead of "supported", as the chapter
  already reads the glycaemic H1 (ch.4, conclusion, abstract, résumé; I49).
- Two limitations added to tab:limitations: search budgets of 15 to 25 configurations, with the
  kept configuration often among the last trials (I50); a state distance that barely registers
  glucose (I51, also in ch.4 §Evolution of the patient's state).
- Test counts: 172 in the research package, 220 in all (one test added for the cross-fitted update).

Compiled without errors, undefined references or overfull boxes: 113 pages. Questions the
jury is likely to ask, with the answers the work supports: §5 below.

**Revision of 3 November 2026, at the author's request.** The 90-page cap is lifted: the thesis
is brought to at least 100 pages by restoring the most useful material cut on 27 October, and
the modern page design is replaced by a standard LaTeX report (Latin Modern 11 pt, 1.5 line
spacing, default chapter headings, black links, a plain bilingual title page; the "Key points"
boxes became a "Synthesis" section at the end of each chapter). What came back:

- Ch.1 follows the school plan in full (introduction to the review; conceptual framework;
  previous work; critical comparison; limits; link with the present research, with a table from
  the limits to RQ1–RQ4; synthesis) and gives each of the nineteen core sources its method,
  results and limits again (WHO report, Gafane, Kingue and Bediang, Dodoo, Segun, Alessa, Mao,
  Zhou with its subgroups, Mihevc, Efendi, Liu, Mendoza, Alhammad); new Appendix A summarises the
  nineteen sources.
- Ch.2: the justification of each labelling threshold and the label-construction figure; label
  recovery against forecasting (figure, four anti-leakage rules); lead time and sampling frequency
  (the reasoning behind H2); families of decision support; the full home protocol.
- Ch.3 follows the school plan in full (introduction; type of research; setting and population,
  with eligibility and collection scenarios; validity and reliability; sampling plan; limitations
  of the methodology; synthesis and transition) and adds the requirements and traceability table
  that RQ1 relies on, the health assistant and its guardrails, the boundary of automation, the
  failure modes and the security segments of the built system.
- Ch.4: an introduction recalling the hypotheses; a wider comparison with the literature; the
  alert-volume tables; strengths of the results; precautions of interpretation; a table of the
  hypotheses and their outcome.

Errors corrected in the same revision: the comparison with the literature said that Efendi et al.
worked on blood pressure and glucose (they measured heart rate, oxygen saturation and
temperature); the review counted its sources as "nineteen peer-reviewed" (eighteen studies and
the WHO report, plus two further studies); the Introduction promised a traceability of the system
to requirements that no table gave; "family" was used both for the eight candidates and for their
five groups (now "families" and "types"); the relabelling by the physician was written as done.

Written and compiling without errors, overfull boxes, undefined references or duplicate labels:
`memoire_restructure.pdf`, **112 pages** (`python parts/build.py`, then `pdflatex`, `biber`,
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

| Part | File | Pages (3 Nov) |
|---|---|---|
| Front matter (title, declaration, abstract, résumé, contents, acronyms, lists) | `00_front.tex` | 13 |
| Introduction | `01_introduction.tex` | 4 |
| Ch.1 Literature review | `02_review.tex` | 22 |
| Ch.2 Risk-tiering framework | `03_framework.tex` | 10 |
| Ch.3 Methodology and system | `04_methodology.tex` | 24 |
| Ch.4 Results and discussion | `05_results.tex` | 19 |
| Conclusion | `06_conclusion.tex` | 2 |
| References | (biblatex) | 7 |
| Appendices A–F | `07_appendices.tex` | 11 |

Still missing: the acknowledgments (after the Declaration) and, if you want them, the logos.
H2 (24 and 48 hours ahead) is reported as not tested until the runs at 12 and 36 h are made.

The old 125-page chapters (`parts/archive_125p/`) and the earlier versions `final_memoire` and
`correction memoir` are kept on the author's machine only, out of git; so is the French
working version (`memoire_fr`, `parts_fr/`, `results_fr/`), which does not receive the
revision of 3 November by itself.

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
| 4.5 System verification | parity tests, rules, offline behaviour, worker; assistant adversarial set | test suites; `integration_test/` | tests yes (172 Python, 48 Flutter); rules deployed 4 Nov; assistant **on a phone** pending |
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
4. On a phone: run the 22-question assistant set (the Firestore rules and index were deployed on 4 November)
   (§4.5 reports both as pending).

## 5. Questions the jury is likely to ask

Each answer uses only what the work shows; the section that supports it is in brackets.

1. **Why develop on intensive-care data for a home system?** No home series of Cameroonian
   patients exists at the scale a benchmark needs. The eICU demonstration subset was harmonised
   to two readings a day, like the Douala charts, and Douala serves only to check the transfer.
   The thesis says what this costs: prevalence and dynamics differ from home, so the model must
   be revalidated on home data before it may raise a tier (ch.3 §Sampling plan; ch.4
   §Precautions; tab:limitations).
2. **A gain of 3 % in RPS: is it useful?** It is significant for blood pressure (five of eight
   families, CatBoost 0.1384 → 0.1341, p = 0.002), but the decision curves show no gain in net
   benefit over the rule on Douala. That is why the design lets the model raise the rule's tier,
   never lower it (ch.2 decision layer; ch.4 §Clinical utility).
3. **Why deploy GRU-D for glucose if it does not beat persistence?** The export follows the
   declared procedure (lowest selection cost on all development data); GRU-D is ahead without a
   significant difference (p = 0.14), the glycaemic task falls short of the sample-size criteria,
   and the rule floor keeps every decision at least at the guideline level (ch.4 §RQ2; script 11).
4. **What can 32 patients tell?** The direction of the transfer only: every model loses
   accuracy and under-predicts the alert, as the prevalences (23 % against 17 %, 59 % against
   29 %) predict. Intervals come from a patient bootstrap and overlap for every pair of models,
   so the Douala comparisons are descriptive (ch.4 §External validation, §Precautions).
5. **Did the deep models get a fair chance?** They had 20 configurations against 25 for
   CatBoost, and the searches had not levelled off; this is why H3 is read as "not rejected",
   not as proven equality. An equal-budget rerun would settle it (tab:limitations; register M1).
6. **Does the intercept update really help?** It removes the offset by construction. Scored
   honestly, with each patient's intercept fitted on the others, it still lowers the Brier
   score (CatBoost 0.148 → 0.146, GRU-D 0.237 → 0.223), but it cannot fix slopes far from one
   (ch.4 §Calibration).
7. **Where do the thresholds come from, and who sets the tier cut-points?** Every labelling
   threshold has an official source (ESH 2023, NEWS2, IHSG/ADA/CMS). The cut-points 0.1 and 0.3
   and the equal weights of the selection cost are provisional until the partner physician
   states the costs of errors; a sensitivity analysis over 1 000 random weightings shows how
   stable the choice is (ch.2; ch.3 §Metrics; configs/cost.yaml).
8. **How reliable are the Douala readings?** The devices are not named; their tolerance alone
   can change the level of a quarter to more than half of the readings. The
   thesis reports this uncertainty instead of hiding it (ch.4 §What the readings say about the
   instruments).
9. **Ethics and data protection?** Research authorisation of the Laquintinie Hospital
   No. 185/AR/MINSANTE/DHL/CM; no ethics committee opinion was provided, which the thesis
   states. Analyses use elapsed time, not dates; the data are not in the repository. The
   assistant receives no name or identifier, and the transfer abroad is discussed under Law
   2024/017 (ch.3 §Ethics, §The health assistant).
10. **Has anyone used the system?** No. It is built and verified by 220 automated tests,
    including the parity of the phone's triage with the Python reference; the pilot, the
    emulator test of the security rules (deployed on 4 November) and the assistant test on a phone are pending (ch.4
    §System verification).
11. **The title says "possibly mobile sensors": where are they?** Readings are entered by hand;
    Bluetooth acquisition and the ESP32 prototype are specified, not built, and appear as
    future work, which the word "possibly" in the registered title allows (ch.3 build status;
    Conclusion).
12. **Can someone reproduce the results?** Every protocol is declared in `configs/` before the
    runs; each run folder keeps its configuration, a copy of the code and every prediction; the
    tables are written by scripts 13 and 15; the library versions are pinned and available as a
    Docker image (ch.3 §Reproducibility; README).
13. **Why is H2 not tested?** The runs at embargoes of 12 and 36 h take about a day and a half;
    the script and the table are ready (§4 point 3). Until they are run, RQ3 is reported as open.
