"""Rule-based severity labels — thesis ch.3 §Labelling.

Each reading gets a severity level per channel from the versioned threshold
table (configs/thresholds.yaml). Within a condition the worst channel governs;
one label is computed per condition, and the overall label is the worst of the
condition labels available at that reading. A missing channel yields a missing
level, never "stable": absence of a measurement is not a normal value.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path
from typing import Mapping

import numpy as np
import pandas as pd
import yaml

DEFAULT_THRESHOLDS = Path(__file__).resolve().parents[2] / "configs" / "thresholds.yaml"

# Units in which readings reach this module (thesis Table "tab:units").
INPUT_UNITS = {"sbp": "mmHg", "dbp": "mmHg", "pulse": "bpm", "glucose": "mmol/L"}

# Glucose molar mass 180.156 g/mol: 1 mmol/L = 18.0156 mg/dL. The cohort was
# converted from g/L with this factor; the rounded 18.0 would move readings at
# exactly 1.80 g/L (180 mg/dL) below the treatment threshold.
MGDL_PER_MMOLL = 18.0156
_FACTORS = {("mmol/L", "mg/dL"): MGDL_PER_MMOLL}

# Converted values are resolved to 1e-6 of the threshold unit before comparison,
# so floating-point error cannot move a reading across a boundary.
_DECIMALS = 6

_OPS = {"lt": np.less, "le": np.less_equal, "gt": np.greater, "ge": np.greater_equal}

# Column of the cohort file holding each channel.
DEFAULT_COLUMNS = {"sbp": "sbp", "dbp": "dbp", "pulse": "hr", "glucose": "glucose"}


@dataclass(frozen=True)
class Rule:
    id: str
    level: int
    op: str
    value: float
    source: str


@dataclass(frozen=True)
class ThresholdTable:
    version: str
    levels: tuple[str, ...]
    units: Mapping[str, str]
    rules: Mapping[str, tuple[Rule, ...]]
    conditions: Mapping[str, tuple[str, ...]]
    variants: Mapping[str, tuple[str, ...]]
    variant_name: str | None = None

    def variant(self, name: str) -> "ThresholdTable":
        """The table with the rules of a sensitivity-analysis variant removed."""
        if name not in self.variants:
            raise KeyError(f"unknown variant {name!r}; known: {sorted(self.variants)}")
        drop = set(self.variants[name])
        rules = {ch: tuple(r for r in rs if r.id not in drop) for ch, rs in self.rules.items()}
        return replace(self, rules=rules, variant_name=name)

    def channel_level(self, channel: str, values) -> np.ndarray:
        """Severity level of each reading of one channel; NaN where not measured."""
        x = np.asarray(values, dtype=float) * _factor(INPUT_UNITS[channel], self.units[channel])
        x = np.round(x, _DECIMALS)
        level = np.zeros(x.shape)
        for r in self.rules[channel]:
            level = np.where(_OPS[r.op](x, r.value), np.maximum(level, r.level), level)
        level[np.isnan(x)] = np.nan
        return level

    def label(self, df: pd.DataFrame, columns: Mapping[str, str] = DEFAULT_COLUMNS) -> pd.DataFrame:
        """Per-channel levels `s_<channel>`, per-condition labels `y_<condition>`
        and the overall label `y` (NaN where no channel was measured)."""
        out = pd.DataFrame(index=df.index)
        for ch in self.rules:
            out[f"s_{ch}"] = self.channel_level(ch, df[columns[ch]].to_numpy())
        for cond, chans in self.conditions.items():
            out[f"y_{cond}"] = _worst([out[f"s_{ch}"].to_numpy() for ch in chans])
        out["y"] = _worst([out[f"y_{c}"].to_numpy() for c in self.conditions])
        return out


def _factor(src: str, dst: str) -> float:
    if src == dst:
        return 1.0
    try:
        return _FACTORS[(src, dst)]
    except KeyError:
        raise ValueError(f"no conversion from {src} to {dst}") from None


def _worst(arrays: list[np.ndarray]) -> np.ndarray:
    """Element-wise maximum ignoring NaN; NaN only where every input is NaN."""
    return np.fmax.reduce(np.vstack(arrays), axis=0)


def load_thresholds(path: str | Path = DEFAULT_THRESHOLDS, variant: str | None = None) -> ThresholdTable:
    """Read and validate the threshold table; optionally apply a variant."""
    cfg = yaml.safe_load(Path(path).read_text(encoding="utf8"))
    levels = tuple(cfg["levels"])
    units, rules, seen = {}, {}, set()
    for ch, spec in cfg["channels"].items():
        if ch not in INPUT_UNITS:
            raise ValueError(f"unknown channel {ch!r}")
        units[ch] = spec["unit"]
        _factor(INPUT_UNITS[ch], units[ch])
        rs = []
        for r in spec["rules"]:
            rule = Rule(r["id"], int(r["level"]), r["op"], float(r["value"]), r["source"])
            if rule.id in seen:
                raise ValueError(f"duplicate rule id {rule.id!r}")
            if rule.op not in _OPS:
                raise ValueError(f"rule {rule.id!r}: unknown op {rule.op!r}")
            if not 1 <= rule.level < len(levels):
                raise ValueError(f"rule {rule.id!r}: level {rule.level} outside 1..{len(levels) - 1}")
            if not rule.source:
                raise ValueError(f"rule {rule.id!r}: no source")
            seen.add(rule.id)
            rs.append(rule)
        rules[ch] = tuple(rs)
    conditions = {c: tuple(chs) for c, chs in cfg["conditions"].items()}
    for c, chs in conditions.items():
        missing = set(chs) - set(rules)
        if missing:
            raise ValueError(f"condition {c!r} uses undefined channels {sorted(missing)}")
    variants = {v: tuple(spec["drop"]) for v, spec in cfg.get("variants", {}).items()}
    for v, drop in variants.items():
        unknown = set(drop) - seen
        if unknown:
            raise ValueError(f"variant {v!r} drops unknown rules {sorted(unknown)}")
    table = ThresholdTable(str(cfg["version"]), levels, units, rules, conditions, variants)
    return table.variant(variant) if variant else table
