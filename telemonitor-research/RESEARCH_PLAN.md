# TeleMonitor — Research plan (part 2: methodology)

The thesis (`memoire/`) is the reference. Code follows the thesis; where the thesis
is wrong, the thesis is corrected first, then the code.

## 1. Standing decisions (2026-10-19)

| # | Decision | Consequence |
|---|---|---|
| D1 | Every model and technology choice comes from a benchmark: an official/published one, or one run in this study | No model is fixed in advance; only the candidate pool and the protocol are |
| D2 | Research code = Python modules (PyTorch for neural models). Notebooks are only for exploration and tests | `TeleMonitor_model_REAL.ipynb` is superseded once the package reproduces it |
| D3 | Metrics are not fixed a priori: admissible metrics are selected by explicit criteria, and their weights in a cost function are calibrated during the search | Weights are tuned in the inner loop only; the outer test folds report every admissible metric unweighted (see §3) |
| D4 | Hyperparameter search over structural hyperparameters (architecture, depth, hidden size, window length…) and training hyperparameters (learning rate, regularisation, class weights…) | Nested, patient-grouped; search space and budget declared before running |
| D5 | Serving API: FastAPI | Local development only |
| D6 | Online hosting is out of scope for this thesis | No hosting section in the thesis |
| D7 | H1 is tested: "a deep temporal model" (the thesis does not name one) enters the benchmark | Which architectures, and which libraries for every family, are decided in step 8 from official benchmarks — nothing is presupposed, including XGBoost or LSTM |
| D8 | Bibliography style: IEEE (school plan) | Done: `build.py` uses style=ieee, sorting=none |
| D9 | Exploratory study; development and benchmark on eICU (demo now, full database under DUA), Douala charts for external validation only | Decided 2026-10-19 after the Riley analysis (step 4) |
| D10 | Selection-cost weights: equal (neutral) for now, replaced by the costs of errors stated by the partner physician | Decided 2026-10-19; configs/cost.yaml status: provisional |
| D11 | Patient-state evolution: no comparison measure assumed (cosine included as a candidate); 8 lock-step candidates from Wang et al. 2013 + patient-scaled and Mahalanobis (control charts), selected by own benchmark (script 12) | Decided 2026-10-21; ch3 §Tracking the evolution; app shows per-channel change, clinician also the selected distance; no alert on the distance |

## 2. Steps (theory first, then code)

1. **Label** — done 2026-10-19: theory in ch3 §Labelling; code `src/telemonitor/labels.py` + `configs/thresholds.yaml`; 38 tests in `tests/test_labels.py`. Old `features.level()` remains until the windowing step replaces it
2. **Measurement validity** — done 2026-10-19: ch3 §Data obtained, §Instruments of the data obtained, quality table, limitations; code `quality.py`, `audit.py` (-> out/audit_cohort.json); tests `test_quality.py`
3. **Problem formulation** — done 2026-10-19: ch3 §windows, §horizon, §formulation (value forecast vs ordinal classification, both benchmarked); code `windows.py` (283 samples, 32 patients at 12 h); tests `test_windows.py`
4. **Sample size** — done: ch3 §Sampling Plan (Riley table, two datasets with distinct roles, eICU harmonisation); `sample_size.py`, `eicu.py`
5. **Features** — done: ch3 §feature families, §budget, §missing data; `features.py` (primary 8, extended 16, descriptors16)
6. **Validation** — done: ch3 §Training protocol (outer by hospital, inner by patient, corrected t test, cluster bootstrap); `validation.py`
7. **Metrics and cost** — done: ch3 §Metrics (admissible measures, selection cost, provisional weights); `metrics.py`, `objective.py`, configs/cost.yaml
8. **Candidates and search** — done: ch3 §Baselines, §Candidate families, §Hyperparameter search; `models/` (tabular, sequence GRU-D/LSTM, levels), `search.py`, configs/benchmark.yaml. **Run pending the eICU demo download**
9. **Calibration and thresholds** — done: ch3 §Risk score (band integration, exact weight correction, no recalibration in development, intercept update in external validation), §Thresholds; `metrics.update_intercept`, `calibration_curve`
10. **Interpretability** — done: ch3 §Interpretability (grouped permutation importance, CatBoost SHAP); `explain.py`
10b. **State evolution** — theory done (ch3 §Tracking the evolution, tab:state-measures, 8 verified references); code `state.py`, `scripts/12_state_comparison.py`, `configs/state_compare.yaml`, service `evolution` block, app EvolutionCard; **benchmark to run by the user**, then set `selected`
11. Deployment — offline engine (rule floor, parity fixture) and online engine (FastAPI) built; model export `scripts/11_export_model.py` built; local worker for the server functions built (§6c). **The deployed model waits for a complete benchmark run**
12. **Reporting** — done for the methods: Appendix A (TRIPOD+AI checklist mapped to sections); items 20–27 with the results; fairness by sex/age and heterogeneity across hospitals added to §Metrics; ethics paragraph on the datasets actually used

## 3. Guardrail on the cost function (D3)

Tuning metric weights on the data that also judge the models is circular: some
weighting will always favour a given model. Therefore:
- training-loss weights (class weights, regression/classification mix) are
  hyperparameters, searched in the inner folds;
- the selection utility's weights come from clinical misclassification costs
  (elicited from the partner physician or derived from the decision threshold),
  are fixed before the outer evaluation, and are varied in a sensitivity analysis;
- the outer folds report every admissible metric separately.

## 3b. Thesis organisation and outputs

The thesis has three parts; part 3 (results and discussion) is **not written yet**. Numbers enter
the methodology only where it needs them (data description, sample size). Every analysis is a
rerunnable script in `scripts/` (guide: `BENCHMARKS.md`). Chapter 3 carries TikZ figures for the
study design, harmonisation, label construction, search and selection, and value-to-level
probabilities.

## 4. Planned package layout (built after the theory of each step is validated)

```
telemonitor-research/
  pyproject.toml
  configs/            thresholds.yaml (versioned, sourced), search spaces, runs
  src/telemonitor/
    data/             loading, audit, cleaning (raw file never modified)
    labels.py         threshold table -> per-channel severity -> levels
    windows.py        windowing, masks, features
    models/           baselines + the candidate families retained in step 8
    objective.py      admissible metrics, cost function
    search.py         nested CV + hyperparameter search
    evaluate.py       metrics, calibration, decision curves, corrected tests
    explain.py        SHAP
    export.py         ONNX export + parity checks
    serve/            FastAPI app (local)
  tests/              pytest (parity Python/ONNX/Dart, labels, windows)
  notebooks/          exploration only
```

## 5. Incoherence register

| # | Where | Incoherence | Resolution (step) |
|---|---|---|---|
| I1 | ch3 tab:threshold-allocation | "130/80 mmHg = ESH classification" — ESH 2023 sets hypertension at 140/90; 130/80 is ACC/AHA 2017 | **Fixed** (ch3 §Labelling, tab:label-thresholds; labels.py) |
| I2 | notebook, features.py | Glucose thresholds 8/11/14 attributed to WHO; WHO only sets 11.1 (diagnosis); 14 ≈ the old DKA criterion (>13.9), replaced in 2024 by ≥11.1 | **Fixed** (thesis + labels.py) |
| I3 | notebook, features.py | No lower thresholds: 71/54 mmHg labelled stable | **Fixed** (NEWS2 red score: SBP ≤90, pulse ≤40/≥131; thesis + labels.py) |
| I4 | app `reading.dart` | ACC/AHA categories and glucose 7.0/11.1, a third labelling rule | **Fixed** (2026-10-20): `lib/services/clinical_levels.dart` mirrors thresholds.yaml, parity-tested against labels.py; every screen uses it |
| I5 | ch3 vs data | Chapter written for scenario B (home devices); data are scenario D (inpatient charts, 2 readings/day) | Scenario declared and limitations rewritten (step 2); window/horizon/sample values at steps 3–4 |
| I6 | notebook | Collection said to be Sept–Oct 2026; data dated 2026-06-08 to 2026-08-30 | **Fixed** in thesis (dates of the readings); notebook superseded |
| I7 | ch3 vs code | Window L = 14 days vs W = 7 readings (~3.5 days) | **Fixed**: time windows L ∈ {24,48,72,96} h searched, fixed anchor set (windows.py) |
| I8 | ch3 vs code | Primary set of 8 features (margins, adherence, static) vs 16 implemented descriptors | Step 5 |
| I9 | notebook, EXPERIMENTS.md | Wilcoxon over 30 re-partitions of the same patients (non-independent) | Step 7 |
| I10 | notebook | Small number mismatches (AUC 0.754 vs 0.751; drop 0.081 vs 0.079) | Regenerated by the package |
| I11 | ch3, H1 | No deep temporal model implemented; ch3 names LSTM and the notebook uses XGBoost without a benchmark justifying either | **Fixed**: pool justified by benchmarks (CatBoost replaces XGBoost); GRU-D and masked LSTM implemented |
| I12 | ch4 | RTDB, MQTT, ESP32, Cloud Functions described as "built"; app uses Firestore, manual entry | Chapter 4 rewrite |
| I13 | app assets | Bundled ONNX corrupted (UTF-8 replacement bytes); app ships the old synthetic model | **Fixed**: old engine and asset removed; offline = guideline rule floor, online = FastAPI service; the benchmark-selected model will be exported for offline use at step 11 |
| I14 | CALIBRATION.md, FINDINGS.md | Synthetic-data results (0.87/0.86) must not appear as results | Thesis results chapter |
| I15 | app | Window = last 7 readings, HR imputed at 75 bpm (never seen in training) | **Fixed**: time window of 96 h, no imputation; features computed by the service with the research code |
| I16 | ch1/ch2 | WHO "78%" and "12% controlled" unverified; Hinneh "144 433 participants" is a sum, not reported by the authors | Chapters 1–2 |
| I17 | ch3 §tools | "realtime database, cloud functions" | **Fixed in ch3** (tools rewritten); ch4 still to rewrite |
| I18 | ch3 §Units | Glucose factor written 18.0; data converted with 18.0156 — 3 readings at 1.80 g/L would cross the 180 mg/dL threshold | **Fixed** (thesis + labels.py, boundary tests) |
| I19 | ch3 tab:units vs data | DBP plausible range 30–160, yet the cohort holds DBP = 24 mmHg | **Fixed**: excluded as impossible (quality.py); 102/100 pair excluded as incoherent |
| I20 | dataset A (consultations) | Impossible or implausible dates: 31/09/2026, 02/01/2016, 19/10/2026 (after the file was made), one row without patient | Descriptive statistics of dataset A must be recomputed with these rows flagged (results chapter) |
| I21 | notebook vs data | "Infection admissions" asserted, but admission diagnoses are not transcribed; eligibility unverifiable | Declared as a limitation (ch3); diagnoses to request from the hospital if possible |
| I22 | ch3 tab:eligibility, tab:assumptions, sampling plan | Still written for scenario B | Steps 3–4 |
| I23 | ch3 §features | Signed margin to a fixed threshold is an affine function of the last value (no information) | **Fixed**: removed, reason stated |
| I24 | ch3 §baselines | Rungs 1 (persistence) and 2 (rule on last value) are the same baseline when the label is the rule | **Fixed**: merged, with transition probabilities |
| I25 | ch3 §metrics, §prereg | Headline metric "recall on the critical class" (improper, threshold-dependent); primary comparison fixed on gradient boosting | **Fixed**: admissible measures, selection cost, no model favoured |
| I26 | eICU demo page | Page says 20 hospitals; the data hold 186 | **Fixed** in thesis (data value) |
| I27 | ch3 §Anonymity vs data | Thesis prescribes age bands and a random date shift; the Douala file holds exact ages and dates | Apply before any sharing of the analysis file (user decision: analysis uses relative times; age is a feature) |
| I28 | ch3 §Ethics | Ethics committee reference and hospital authorisation for the Douala charts not known | **User to provide** |
| I29 | Appendix A item 18a–b | Funding and conflicts statement not in the front matter | **User to provide** |
| I30 | eICU demo | vitalPeriodic.csv.gz download repeatedly interrupted (PhysioNet rate) | **Fixed**: complete, SHA-256 verified (2026-10-20) |
| I31 | ch1–ch2 vs data | Title, question and objective 2 promised home data and models developed on own data | **Fixed** (2026-10-20): ch1 §Scope and data actually used; objective 2 rewritten |
| I32 | ch2 §cascade | "Largest loss at the last link" contradicted by 57 % undiagnosed vs 56 % uncontrolled | **Fixed**: argument rebuilt on 72 % of diagnosed patients not controlled |
| I33 | ch2 hypotheses | H1 stated in recall on local telemonitoring data; RQ1 without method; "framing document" never cited | **Fixed**: H1–H4 on RPS/persistence/lead time/transport; RQ4 added; RQ1 answered by design and traceability |
| I34 | ch2 | ESH "130/80"; Zhou p = .09 read as an effect; Bediang retention row copied; Mihevc "117 analysed"; Mucchi layers inconsistent | **Fixed** |
| I35 | ch3 §training | Inner folds said to fit calibration and thresholds; "split forward in time"; "single-site"; LR imputation vs "never imputed"; GRU-D towards patient mean; per-patient normalisation not implemented | **Fixed**: text aligned on the code (no recalibration, thresholds from costs, hospital/patient split, training-mean decay, absolute units) |
| I36 | ch3 tab:assumptions, tab:meth-summary | Still scenario B, XGBoost/LSTM, recall, ten repeats | **Fixed** (I22 closed): scenario D, actual pool, 3 repeats |
| I37 | ch3 home-protocol sections | Prospective procedure, Bluetooth instruments and schema written as done | **Fixed**: moved to ch4 §The Home Monitoring Protocol, conditional |
| I38 | ch3 unjustified constants | n0 = 20, ±2 h slots, 10–20 % relabelling, date shift, π = 0.02 | **Fixed**: scripts 09 and 10; relabel ≈ 100–150 readings; date shift replaced by elapsed time; π stated as planning assumption |
| I39 | ch3 §legal | Cameroonian law not named | **Fixed**: Law 2024/017 (in force June 2026) and Law 2010/012 |
| I40 | ch4 vs code | RTDB, MQTT, BLE, Cloud Functions, priority queue described as built (I12, I17) | **Fixed**: ch4 describes Firestore + FastAPI risk service + roster; build-status table rewritten |
| I41 | app vs ch4 spec | Readings editable/deletable by the patient (spec: append-only); risk card shows probabilities to the patient (spec: never); single reading, no back-dating | **Fixed in the app** (2026-10-20, §6c); ch4 text to align |
| I42 | app, health assistant | Gemini assistant absent from the thesis; sends name, conditions, medications and readings to Google (transfer abroad, Law 2024/017); prompt says risk from "last seven readings" (card uses 96 h) | Thesis: **Fixed** (ch4 §The health assistant, guardrails and limits). App: **fixed** (2026-10-20, §6c); adversarial set to run by the user |
| I43 | appendix A | Items 2 (abstract) and 18a–b (funding) pointed to absent front matter | **Fixed**: rows removed (I29 closed) |

## 6. Remaining work (2026-10-20)

Nothing below is done yet. Statuses are updated here as each item is closed.

### 6a. Depends on the user (no text can be written without it)

| # | Missing | Where it is required | Register |
|---|---|---|---|
| U1 | Ethics committee reference and written hospital authorisation for the Douala charts | ch3 §Ethics; Appendix A item 17 | I28 |
| U2 | Blind relabelling by the physician of ≈ 100–150 readings (rule not shown) | ch3 §Labelling (secondary criterion); size from script 09 | I38 |
| U3 | Error costs stated by the physician: final risk-tier thresholds (now 0.1 / 0.3, provisional) and selection-cost weights (now equal) | ch3 §Metrics, §Thresholds; configs/cost.yaml, serve.yaml | D10 |
| U4 | Admission diagnoses of the 32 Douala patients, to confirm hypertension or diabetes | ch3 limitation no. 6 | I21 |
| U5 | Four confirmations: name of the "framing document"; whether the ESP32 prototype was built; physician's role ("facilitated access to records"); authors of Moore 2017 | ch3, ch4 | I33 |

### 6b. Data and analyses

| # | Missing | Note |
|---|---|---|
| A1 | Full eICU database (PhysioNet credentialed account, CITI training, signed DUA) | Otherwise the thesis must state that the benchmark uses the demo subset only |
| A2 | Final results of the full benchmark (`06_benchmark.py`, ≈ 12 h per task) and of the Douala external validation | Run by the user |
| A3 | Performance by sex and by age band (< 65 / ≥ 65) | Promised in ch3 §Metrics; not in the code |
| A4 | Benchmark rerun with the variant capping severe hyperglycaemia at "high" | Variant exists in `02_label_rules.py`, not in the benchmark |
| A5 | Benchmark rerun with slot tolerances ± 1 h and ± 3 h | Script 10 only counts samples |
| A6 | Descriptive statistics of dataset A (consultations) recomputed with impossible dates flagged (e.g. 31/09/2026) | I20 |
| A7 | Anonymisation of the Douala file before any sharing (age bands, dates replaced by elapsed time) | I27 |
| A8 | Cost per patient per month at the scale of 1,000 patients | Promised in ch4 |

Already present (no action): weight sensitivity analysis (Dirichlet draws in `objective.py`).

### 6c. Application (gaps with ch4)

Status 2026-10-20: built in the app (35 Flutter tests pass, `flutter analyze` clean). Not yet
run on a device; Firestore rules not deployed (`firebase deploy --only firestore:rules`, by
the user); rules not tested in the emulator (no Java on this machine).

| # | Gap | Status |
|---|---|---|
| P1 | Record not append-only | **Built**: rules refuse update/delete of readings and validate each write (ranges, pressure pair, unit, measurement time ≤ 30 days back, server record time); a correction is a new reading with `supersedes`, the old one stays and is shown to the clinician as replaced |
| P2 | Risk card shows the probability to the patient | **Built**: patient sees tier, reason and the permitted instruction (yellow: contact the health centre; red: seek care today); calibrated probability and model shown to the clinician only |
| P3 | Assistant receives the name; "7 readings" | **Built**: name and identifiers removed from the instruction; readings = the risk card's four-day window (corrections applied, at most 20) |
| P4 | No adversarial test of the guardrails | **Built**: fixed set of 24 questions FR/EN (`integration_test/adversarial_set.dart`), automatic flags (`guardrail_check.dart`), device runner with JSON report (`integration_test/README.md`). **To run by the user** on a device; breaches confirmed by reading |
| P5 | Protocol pair, back-dating, priority queue, verdicts and event log, non-transmission alarm | **Built**: two BP readings (second retained, first kept for audit); measurement time up to 7 days back; event record `users/{id}/events` (rule and model escalation from the phone, non-transmission sweep from the clinician app, verdict closes once); queue tab ordered red > yellow then oldest, rows with source, triggering value, 14-day trend, days since review, pseudonym and age band, versions; checkup period per patient (default 3 days, provisional) |

Update 2026-10-21 (user decision: local Python worker, no Cloud Functions):

| # | Item | Status |
|---|---|---|
| P6 | Server functions of tab:triggers | **Built**: `serve/worker.py` + `configs/worker.yaml` (measurement check with quality flags, rule and model escalation with the apps' event ids, notification by level and recipient, non-transmission sweep, queue-age escalation to a named alternate, verdict notice to the patient); 11 tests with an in-memory store. Needs a Firebase service-account key (user) |
| P7 | Push notifications | **Built**: `firebase_messaging`, device tokens on the profile, removed at sign-out; sent by the worker |
| P8 | Alternate clinician | **Built**: set from a colleague's enrolment code; escalated events readable and closable by the alternate only (rules + collection-group index) |
| P9 | Deployed model | **Built**: `scripts/11_export_model.py` (lowest selection cost in the final search on all eICU; refuses another threshold version); **waits for a complete benchmark run** |
| P10 | Design review | **Done**: one colour per level everywhere (critical red, high amber), level vocabulary of the thesis in the history, no empty SpO2 card, no duplicate add button, neutral trend series, target band in green, axis labels, plain field labels, muted text at AA contrast, dark-mode fixes; captures in `telemonitor/test_screens` |
| — | Read receipts of messages | **Fixed**: the rules refused them silently |

Still not built: SMS fallback, nurse worklist, interval enforced by a Bluetooth device, online
hosting (out of scope). Android build not verified here (artifact download failed on this
network); Firestore rules and index not deployed (user).

Thesis aligned on 2026-10-22 (conformity check, below).

### 6d. Conformity check thesis / implementation (2026-10-22)

User request: check the solution against the thesis, remove Docker, review the UI and UX.

**Docker removed** (user decision): compose file, Dockerfiles, `.dockerignore`, WSL/Docker
installers, `INFRA.md`; pinned versions kept as `requirements-lock.txt` (no Docker).

**Code brought to the thesis**

| # | Thesis requirement | Gap found | Fix |
|---|---|---|---|
| C1 | ch3 §Labelling: "a home deployment would substitute the out-of-office thresholds of tab:thresholds"; ch4 §triage | The app triaged home readings with the in-hospital label thresholds | Home triage of Mihevc et al. versioned in `configs/home_protocol.yaml`, `home_protocol.py` (35 tests), Dart mirror `home_protocol.dart` with parity fixture (script 07); per-reading levels, risk card, events and worker now green / yellow / red under the home protocol; glucose target by measurement context |
| C2 | tab:requirements "verification profile on the yellow level"; fig:decision-flow, fig:triage | Not built | Seven-day BP profile and one-day six-point glucose profile: progress card for patient and clinician, mean against the target, off target -> red event (`profile_*`), incomplete reported as such (completeness from stergiou2021) |
| C3 | Decision flow: "the patient receives repeated reminders" | One reminder per silence | Worker reminds daily while the non-transmission event is open (`reminder_interval_hours`) |
| C4 | tab:profiles: patient views the outcome of clinician decisions | Only an optional chat message | "From your clinician" card: action and comment of reviewed events |
| C5 | ch4 §Dashboard: "show the same window as the patient's application" | No chart for the clinician | Shared 14-day `TrendChart` in the patient record |
| C6 | ch4 §Offline operation, §Data flow (local warning at red whatever the connectivity) | Saving waited for the server (spinner forever offline); no local warning | Saves never wait for the server (readings, messages, verdicts); unsent readings shown; red reading -> immediate warning dialog |
| C7 | tab:bct-mapping: explanation of the target band, fixed schedule | Absent | Text under the chart; band corrected to 110-134 mmHg (below 110 is red at home) |
| C8 | tab:notification yellow: prompt for the verification profile | Generic text | Worker yellow text points to the check |

**Thesis brought to the code** (status only, no design change): tab:build-status,
tab:collections, tab:access-matrix, §Data model, §Offline operation, §Authentication, §Risk
service + worker paragraph, tab:triggers, §Patient app (what is built, manual entry, trends),
tab:notification, §Health assistant (context, limits), §Dashboard (what is built), §Edge
inference, §Summary limits; five open points of the home protocol stated in §triage;
stergiou2021 added; software tools: lock file.

**Incoherences of the thesis fixed**

| # | Where | Incoherence | Resolution |
|---|---|---|---|
| I44 | tab:notification | Green readings said to "appear in the queue", whereas the queue holds events and green raises none | Green: visible in the record, not queued |
| I45 | tab:automation-boundary vs §Data flow, §Edge inference | Boundary forbids urgency beyond "contact your health centre" while the red local warning tells to seek care | Exception stated: red warning = contact the health centre the same day, hospital at once with emergency symptoms |
| I46 | §Data model | "One row per measurement" vs one document per session in Firestore | Stated: a session document, reshaped without loss to the measurement layout |
| I47 | §Patient app, trend band | Band drawn from the bottom of the chart to 135, though below 110 is red | Band 110-134 |

**UI/UX review**: patient shell with four tabs and a "Log a reading" button (only the visible
tab is built, so the chat does not stay "online" or mark messages read behind another tab);
plain wording for the patient (no "risk service not configured"); context required for
glucose; pulse field readable at 130 % text; values scaled down instead of cut in the
history; context moved out of the truncated header; profile card wording; smallest captions
raised to 11; captures at 130 % text without overflow (`test_screens`, 28 captures).

**Tests**: Python 171, Flutter 48 (+ 28 captures). Not run on a device; rules and index not
deployed (user).
