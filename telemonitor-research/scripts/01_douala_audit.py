"""Step 2 — audit of the Douala inpatient charts.

Reproduces (thesis ch.3 §Data obtained, §Instruments of the data obtained, §Quality controls):
  * cohort description: 32 patients, 366 readings, 8 June - 30 August 2026, 12 h rhythm;
  * quality flags: DBP 24 mmHg out of range, 102/100 incoherent pair, carried-forward runs, extremes;
  * terminal-digit analysis: SBP/DBP uniform (electronic device), pulse even digits (read from the curve);
  * label uncertainty under ISO 81060-2 / ISO 15197 tolerances (27% SBP, 39% DBP, 56% glucose);
  * label distribution, main rule and capped-hyperglycaemia variant.
Output: out/audit_cohort.json
"""
import _common  # noqa: F401  (sets the import path)
from telemonitor.audit import main

if __name__ == "__main__":
    main(["audit", str(_common.DOUALA)])
