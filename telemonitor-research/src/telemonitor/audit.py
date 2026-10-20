"""Audit of the modelling cohort: quality controls, measurement validity, labels.

Run:  python -m telemonitor.audit  [cohort.csv]  ->  out/audit_cohort.json
The numbers feed the description of the cohort in the results chapter.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd

from . import quality as Q
from .labels import load_thresholds

ROOT = Path(__file__).resolve().parents[2]


def audit(path: Path) -> dict:
    raw = pd.read_csv(path, parse_dates=["date"])
    qc = Q.check(raw)
    d = qc.clean
    table = load_thresholds()
    rep = {
        "file": path.name,
        "threshold_version": table.version,
        "cohort": {
            "patients": int(d.patient.nunique()),
            "readings": int(len(d)),
            "first_date": str(d.date.min().date()),
            "last_date": str(d.date.max().date()),
            "readings_per_patient": d.groupby("patient").size().describe().round(1).to_dict(),
            "slots_per_day": {int(k): int(v) for k, v in d.groupby(["patient", "date"]).size().value_counts().items()},
            "max_gap_days": float(d.groupby("patient").date.apply(lambda s: s.diff().dt.days.max()).max()),
            "availability": {c: round(float(d[c].notna().mean()), 4) for c in Q.CHANNELS},
            "patients_without_glucose": int((d.groupby("patient").glucose.count() == 0).sum()),
        },
        "quality_flags": qc.summary(),
        "terminal_digits": {c: Q.terminal_digits(d[c]) for c in ("sbp", "dbp", "hr")},
        "label_uncertainty_under_device_tolerance": Q.label_uncertainty(table, d),
    }
    for name, t in (("main", table), ("cap_severe_hyperglycaemia", table.variant("cap_severe_hyperglycaemia"))):
        lab = t.label(d)
        rep[f"labels_{name}"] = {
            col: {int(k): int(v) for k, v in lab[col].value_counts().sort_index().items()}
            for col in ("y_haemodynamic", "y_glycaemic", "y")
        }
    return rep


def main(argv: list[str]) -> None:
    path = Path(argv[1]) if len(argv) > 1 else ROOT / "cohortB_complete.csv"
    rep = audit(path)
    out = ROOT / "out" / "audit_cohort.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(rep, indent=1), encoding="utf8")
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main(sys.argv)
