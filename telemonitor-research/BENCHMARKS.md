# Rerunning the analyses and benchmarks

Every number in part 2 of the thesis (methodology) is produced by a script in `scripts/`. The
protocols are declared in `configs/` before any run, and the tested code lives in
`src/telemonitor/`.

## 1. Installation

From the folder `C:\Projects\telemonitor-research`:

```
python -m venv .venv
.venv\Scripts\activate            (Windows)   |   source .venv/bin/activate  (Linux/Mac)
pip install -e .[test,bench,serve]
python -m pytest                  (the whole test suite must pass)
```

A virtual environment (`.venv`) is recommended: it avoids modifying the system Python.
To reproduce exactly the versions used for the thesis, follow the header of
`requirements-lock.txt`.

## 2. Data

| Data | Location | Origin |
|---|---|---|
| Douala inpatient charts (scenario D) | `cohortB_complete.csv` | transcription of the observation charts |
| Douala consultations (scenario A) | `data/patient_data_REAL_DO_NOT_MODIFY.csv` | never modify |
| eICU demo 2.0.1 | `data/external/eicu-demo-2.0.1/` | https://physionet.org/content/eicu-crd-demo/2.0.1/ (open access) |

For the eICU demo, download at least `patient`, `diagnosis`, `pastHistory`,
`vitalAperiodic`, `vitalPeriodic`, `lab` (`.csv.gz` files) and `SHA256SUMS.txt` into that
folder. The code checks the SHA-256 checksums before any use. The folder is excluded from
git.

The full eICU database (final benchmark) requires a PhysioNet account, the CITI training
"Data or Specimens Only Research" and the signature of the data use agreement. Once
downloaded, place it in a folder with the same structure and point `DEMO` in
`scripts/_common.py` to that folder.

## 3. The scripts, in the order of the methodology

| Script | Step | What it reproduces | Duration |
|---|---|---|---|
| `01_douala_audit.py` | 2 | cohort description, quality controls, terminal digits (electronic device), label uncertainty (27 / 39 / 56 %), distributions → `out/audit_cohort.json` | seconds |
| `02_label_rules.py` | 1 | old rule against the sourced rule, capped variant, 103 readings reclassified if all NEWS2 bands are used → `out/label_rules.csv` | seconds |
| `03_pca_exploration.py` | — | exploratory PCA of the old pipeline (≈ 7 effective dimensions; logistic regression on 2 components ≈ XGBoost on 16 variables) | ≈ 5 min |
| `04_sample_size.py` | 4 | Riley criteria (Douala and eICU demo), parity with `pmsampsize` (n = 662); option `--no-eicu` | ≈ 2 min |
| `05_eicu_cohort.py` | 4 | eICU eligibility, harmonisation to the rhythm of the charts, samples and prevalences | ≈ 1 min |
| `06_benchmark.py` | 6–9 | nested benchmark on eICU and external validation on Douala → a run folder `out/runs/<task>_<lead>h_<id>/` (see below) | `--quick`: minutes; full: ≈ 12 h per task |
| `07_app_parity_fixture.py` | 11 | parity fixtures for the Flutter app (`flutter test`): label levels (`thresholds.yaml`) and home triage with verification profile (`home_protocol.yaml`); rerun after any change to either table | seconds |
| `08_figures.py` | — | redraws every figure of a run from its saved outputs, without recomputing → `<run>/figures/` (PDF, PNG and CSV of the plotted values) | seconds |
| `09_kappa_sample_size.py` | 2 | size of the sample to be relabelled by the physician: half-width of the CI of the weighted kappa ≤ 0.10 → ≈ 100 readings (κ ≈ 0.75) to 150 (κ ≈ 0.6) | ≈ 1 min |
| `10_sensitivity_flags_slots.py` | 3–4 | sensitivity to the MAD n₀ (5 / 7 / 9 readings flagged for n₀ = 10 / 20 / 40) and to the eICU slot tolerance (± 1 / 2 / 3 h → 645 / 1 356 / 1 983 glycaemic samples); option `--no-eicu` | ≈ 1 min |
| `12_state_comparison.py` | 10b | benchmark of the 8 state-comparison measures (cosine, Euclidean, Manhattan, Chebyshev, Mahalanobis; `configs/state_compare.yaml`): AUROC for a change of level and for a new alert, eICU development, Douala external check → `out/state_comparison.csv/.json`, scales → `artifacts/state_scales.json`. Then record the chosen measure in `configs/state_compare.yaml` (`status: selected`, `selected: <measure>`) | ≈ 1 min |
| `11_export_model.py` | 11 | exports the chosen model (the family with the lowest selection cost in the final search on all of eICU) from a **full** run to `artifacts\<task>\`, read by the service and the worker; refuses a run labelled with other thresholds | seconds |
| `13_results_tables.py` | — | LaTeX tables of the results chapter from the saved outputs of the runs (RPS, Brier, AUROC, calibration, net benefit per candidate, difference from persistence with the corrected resampled t test; external validation on Douala) → `..\memoire\results\`; refuses an incomplete run (`--partial` for a look only, never for the thesis) | seconds |
| `14_thesis_data_figures.py` | 2–5 | data behind the descriptive figures of the thesis (value distributions, level transitions, Riley curves, Douala timeline) → `..\memoire\figures\data\`; the per-reading Douala file it writes is ignored by git | ≈ 1 min |

Examples (from `C:\Projects\telemonitor-research`):

```
python scripts\01_douala_audit.py
python scripts\04_sample_size.py --no-eicu
python scripts\06_benchmark.py --quick
python scripts\06_benchmark.py --tasks haemodynamic
python scripts\06_benchmark.py --tasks glycaemic --leads 0 12 36
python scripts\08_figures.py                 (latest run)   |   --all   |   --run out\runs\<folder>
```

The two tasks can run in parallel, in two terminals.

### Run folder: the saved outputs that allow the figures to be redrawn

Each run is saved in `out\runs\<task>_<lead>h_<id>\`, where `<id>` is a fingerprint of
what determines its results: task, lead time, candidates, effective configurations, data
checksums.

| File | Content |
|---|---|
| `manifest.json` | identity, inputs, computing sessions (date, version and git state of the code, Python environment, command), progress, status |
| `config\` | the configurations actually used |
| `code\<version>\` | copy of the code (`src\telemonitor`, `scripts\`) for each version used |
| `folds.csv` | results per outer fold and per model |
| `trials.csv` | every hyperparameter trial: parameters, inner measures, cost, configuration kept |
| `predictions\outer\r<repeat>_f<fold>\<model>.npz` | predictions of each outer fold: sample, patient, observed level, probabilities |
| `external\` | Douala predictions, measures (`external.csv`), final models (`models\*.joblib`) |
| `summary.json`, `figures\` | final summary; figures redrawn by `08_figures.py` |

Files are written atomically, and a fold is saved only once it is complete.

**Resuming.** An interrupted run is restarted with the **same command**: same fingerprint,
hence same folder, and the folds already saved are kept. Changing a configuration or the
data creates a new folder, without overwriting the old one.

**Long runs on Windows**, one window per task with the progress bars (absolute path, from
any folder):

```
powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\rerun_benchmarks.ps1
```

The log `out\runs\<run>\run.log` gives, for each fold and each candidate, the duration and
the external RPS. Closing a window stops the run; the same command resumes it.

## 4. Where to change a choice

| Choice | File | Note |
|---|---|---|
| Labelling thresholds, sensitivity variant | `configs/thresholds.yaml` | each rule cites its source (key of `references.bib`, checked by the tests) |
| Weights of the cost function, net-benefit thresholds | `configs/cost.yaml` | provisional until the partner physician answers |
| Folds, repeats, search spaces, budgets | `configs/benchmark.yaml` | to be fixed **before** a run, then reported |
| Green / yellow / red tiers of the service | `configs/serve.yaml` | provisional |
| Home triage, verification profile | `configs/home_protocol.yaml` | thresholds of Mihevc et al. (2025); then `07_app_parity_fixture.py` and update `lib/services/home_protocol.dart` |
| Worker delays (escalation, reminders) | `configs/worker.yaml` | provisional |
| State-comparison measures | `configs/state_compare.yaml` | `selected` after `12_state_comparison.py` |

## 5. Old pipeline (for the record)

`train.py`, `features.py`, `TeleMonitor_model_REAL.ipynb` and the `experiment*.py` /
`verify_*.py` scripts at the root are the old pipeline. They are kept only to reproduce
earlier figures (for example: forecast at 0.425 against 0.452 for persistence with
`python train.py`). The figures in `CALIBRATION.md`, `FINDINGS.md` and `EXPERIMENTS.md`
come from **synthetic data** and must not be presented as results. The files
`out\benchmark_*.csv` from the first attempt (19–20 October) contain neither the trials nor
the predictions: they cannot be used to redraw the figures.

## 6. Local service (FastAPI)

In PowerShell:

```powershell
$env:TELEMONITOR_ARTIFACTS = "artifacts"          # folder containing haemodynamic/ and glycaemic/
uvicorn telemonitor.serve.app:app --app-dir src --host 0.0.0.0 --port 8000
```

(In `cmd`, write `set TELEMONITOR_ARTIFACTS=artifacts` instead.)

For the app to use it on an Android emulator (`10.0.2.2` is the host machine):

```
cd C:\Projects\telemonitor
flutter run --dart-define=RISK_API_URL=http://10.0.2.2:8000
```

For the web version in Chrome, allow its origin before starting the service, and give the
app a fixed port:

```powershell
$env:TELEMONITOR_CORS = "http://localhost:5000"
flutter run -d chrome --web-port 5000 --dart-define=RISK_API_URL=http://localhost:8000
```

Without `RISK_API_URL`, the app applies only the clinical rule (floor), offline.

`GET /health` and `POST /v1/risk`; the interactive documentation is available at
`http://127.0.0.1:8000/docs`.

After a full benchmark: `python scripts\11_export_model.py`, then restart the service.
Without artifacts, the service applies only the rule (floor).

## 7. Local worker: the server functions of chapter 4

`src/telemonitor/serve/worker.py`, settings in `configs/worker.yaml` (provisional delays).
At each cycle (60 s), for each patient:

| Function | What it does |
|---|---|
| Measurement check | quality flag (`quality.py`) written on each new reading |
| Escalation | yellow or red reading according to the home triage (`home_protocol.yaml`, the rule of the app) → "rule" event (same identifier as the one written by the phone: never a duplicate) |
| Score | last reading → rule + model (same code as the API); a model that raises the level → "model" event |
| Notification | each new event, once: red → patient and clinician; yellow → patient; never a dose instruction |
| Non-transmission | no reading since the checkup period → event and reminder to the patient, repeated every day while the silence lasts |
| Queue age | event open for too long (red 4 h, yellow 72 h) → passed to the alternate named by the clinician, both notified |
| Verdict | event closed → the patient is told of the review |

Readings and events older than 24 h found at the first start are marked without being
notified (no avalanche). The SMS fallback is not built.

A Firebase service-account key is required (Firebase console → Project settings →
Service accounts → Generate new private key), saved as `secrets\service-account.json`
(folder excluded from git; never share it). In a virtual environment (firebase-admin
requires another httpx version than other tools installed on this machine):

```
python -m venv .venv
.venv\Scripts\activate
pip install -e .[serve,worker]
python -m telemonitor.serve.worker --credentials secrets\service-account.json --once    (one cycle, to test)
python -m telemonitor.serve.worker --credentials secrets\service-account.json           (continuously)
```
