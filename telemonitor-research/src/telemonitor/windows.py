"""Forecast samples — thesis ch.3 §Irregular sampling and windows, §Formulation.

A sample is anchored at a reading t (the last input reading). Its input window
holds the patient's readings in (t - L, t]; its target is the first reading
after t + eps (the embargo), so input and label never share an observation and
eps sets the lead time tested by H2. Windows are defined in time, not in count.

The set of anchors does not depend on L: an anchor is eligible when the
shortest window considered (L_MIN) holds at least MIN_BP_READINGS blood
pressure readings. Every window length is therefore evaluated on the same
targets, which keeps window length a fair hyperparameter.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from .labels import ThresholdTable

# Charts record a morning (M) and an evening (S) slot without the hour; they are
# placed 12 h apart. Every interval in the cohort is then exactly 12 h.
SLOT_HOUR = {"M": 8, "S": 20}

L_MIN = 24.0           # hours: the shortest window considered
MIN_BP_READINGS = 2    # readings needed for a level (three are needed for a slope)


def add_time(df: pd.DataFrame) -> pd.DataFrame:
    """Hours since the first date of the cohort, sorted by patient and time."""
    t = (df["date"] - df["date"].min()).dt.days * 24 + df["time"].map(SLOT_HOUR)
    return df.assign(t=t.astype(float)).sort_values(["patient", "t"], kind="stable").reset_index(drop=True)


@dataclass
class SampleSet:
    """Anchors and targets; windows are cut on demand for a given L."""
    data: pd.DataFrame      # readings with time `t`, row positions are the reference
    meta: pd.DataFrame      # one row per sample: patient, anchor, target, lead_h, labels
    eps: float

    def window(self, k: int, L: float) -> np.ndarray:
        """Row positions of the input window of sample k for window length L (hours)."""
        a = self.meta.anchor.iat[k]
        p, ta = self.data.patient.iat[a], self.data.t.iat[a]
        rows = self._rows[p]
        t = self.data.t.to_numpy()[rows]
        return rows[(t > ta - L) & (t <= ta)]

    def __post_init__(self):
        self._rows = {p: g.index.to_numpy() for p, g in self.data.groupby("patient")}

    def __len__(self) -> int:
        return len(self.meta)


def make_samples(df: pd.DataFrame, table: ThresholdTable, eps: float = 0.0) -> SampleSet:
    """Build the forecast samples of a cleaned cohort for embargo eps (hours).

    Target labels are those of `table` at the target reading; a condition label
    is NaN where its channels were not measured at the target, so each task is
    evaluated only on the targets where its label exists."""
    data = add_time(df)
    lab = table.label(data)
    rows = []
    for p, g in data.groupby("patient"):
        idx, t = g.index.to_numpy(), g["t"].to_numpy()
        sbp_seen = g["sbp"].notna().to_numpy()
        for j in range(len(idx)):
            later = np.flatnonzero(t > t[j] + eps)
            if len(later) == 0:
                continue
            in_min_window = (t > t[j] - L_MIN) & (t <= t[j])
            if sbp_seen[in_min_window].sum() < MIN_BP_READINGS:
                continue
            tgt = idx[later[0]]
            rows.append((p, idx[j], tgt, t[later[0]] - t[j]))
    meta = pd.DataFrame(rows, columns=["patient", "anchor", "target", "lead_h"])
    # the split unit: a patient may have several sequences (eICU unit stays)
    meta["group"] = data["group"].to_numpy()[meta["anchor"].to_numpy()] if "group" in data else meta["patient"]
    for col in ("y_haemodynamic", "y_glycaemic", "y"):
        meta[col] = lab[col].to_numpy()[meta["target"].to_numpy()]
    # channel values at the target, for the value-forecast formulation
    for c in ("sbp", "dbp", "hr", "glucose"):
        meta[f"v_{c}"] = data[c].to_numpy(float)[meta["target"].to_numpy()]
    # the overall alert is evaluated only where both condition labels exist
    both = meta["y_haemodynamic"].notna() & meta["y_glycaemic"].notna()
    meta["y_both"] = meta["y"].where(both)
    return SampleSet(data, meta, float(eps))
