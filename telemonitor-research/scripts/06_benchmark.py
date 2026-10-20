"""Steps 6 to 9 — nested benchmark on eICU and external validation on Douala.

Runs the protocol declared in configs/benchmark.yaml and configs/cost.yaml:
outer folds grouped by hospital, inner folds grouped by patient, Optuna search per candidate,
selection by the selection cost, evaluation once per outer fold; then every candidate is fitted
on all development data and applied once to the Douala charts (patient-level bootstrap,
intercept update).

Examples
  python scripts/06_benchmark.py --quick                       # pipeline check, minutes
  python scripts/06_benchmark.py --tasks haemodynamic          # full protocol, one task (hours)
  python scripts/06_benchmark.py --tasks glycaemic --leads 0 12 36
  python scripts/06_benchmark.py --candidates ordinal_logistic catboost --quick

Outputs: one run folder per task and lead, out/runs/<task>_<lead>h_<id>/ (tracking.py):
configurations, code, environment, fold results, every trial, every prediction, final
models, summary. The same command resumes an interrupted run; scripts/08_figures.py
redraws its figures.
"""
import _common  # noqa: F401
from telemonitor.run import main

if __name__ == "__main__":
    main()
