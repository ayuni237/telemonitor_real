"""Benchmark of the measures comparing a patient's current state with their
baseline — thesis ch.3 §Tracking the evolution of the patient's state.

Candidates and protocol are declared in configs/state_compare.yaml. For every
forecast sample (anchor t), the current state (t - 24 h, t] is compared with
the baseline (t - 96 h, t - 24 h] by each measure; a measure is useful if its
distance ranks the samples where the patient's level changes at the next
reading above those where it does not. Scales and covariances are fitted on
the development data (eICU demo); the Douala charts are an external check.

    python scripts/12_state_comparison.py            (about a minute)

Writes out/state_comparison.csv (one row per data set, outcome and measure)
and out/state_comparison.json (selection), and prints both.
"""
from __future__ import annotations

import json

import numpy as np
import pandas as pd
import yaml

import _common
from telemonitor import metrics as M
from telemonitor import state as S
from telemonitor import validation as V
from telemonitor.labels import load_thresholds
from telemonitor.progress import progress
from telemonitor.windows import make_samples

CFG = yaml.safe_load((_common.ROOT / "configs" / "state_compare.yaml").read_text(encoding="utf8"))


def frame(samples, table, scales):
    """States, distances of every candidate and the two outcomes, on the samples
    where every candidate is defined."""
    st = S.states(samples, CFG["current_hours"], tuple(CFG["baseline_hours"]))
    shared = (np.isfinite(S._cur(st)) & np.isfinite(S._base(st))).sum(axis=1)
    base_level = S.state_level(table, st, "base")
    target = samples.meta["y"].to_numpy()
    out = pd.DataFrame({"group": samples.meta["group"].to_numpy(), "shared": shared,
                        "level_change": (np.abs(target - base_level) >= 1).astype(float),
                        "new_alert": ((base_level < 2) & (target >= 2)).astype(float),
                        "new_alert_eligible": base_level < 2},
                       index=samples.meta.index)
    ok = np.isfinite(base_level) & np.isfinite(target) & (shared >= CFG["min_channels"])
    for name in CFG["candidates"]:
        out[name] = S.MEASURES[name](st, scales, CFG["min_channels"])
        ok &= np.isfinite(out[name].to_numpy())
    return st, out[ok]


def evaluate(df: pd.DataFrame, data: str) -> list[dict]:
    rows = []
    for outcome in (CFG["primary_outcome"], CFG["secondary_outcome"]):
        d = df[df["new_alert_eligible"]] if outcome == "new_alert" else df
        y, g = d[outcome].to_numpy(), d["group"].to_numpy()
        for name in progress(CFG["candidates"], desc=f"{data} {outcome}", unit="measure"):
            x = d[name].to_numpy()
            auc, lo, hi = V.cluster_bootstrap(lambda i: M.auroc(x[i], y[i]), g, n_boot=CFG["bootstrap"],
                                             seed=CFG["seed"])
            rows.append({"data": data, "outcome": outcome, "measure": name, "n": len(d),
                         "patients": len(np.unique(g)), "events": int(y.sum()),
                         "auroc": round(auc, 4), "lo": round(lo, 4), "hi": round(hi, 4)})
    return rows


def select(res: pd.DataFrame) -> dict:
    dev = res[(res.data == "development") & (res.outcome == CFG["primary_outcome"])].set_index("measure")
    best = dev.auroc.idxmax()
    lo, hi = dev.loc[best, "lo"], dev.loc[best, "hi"]
    # the simplest candidate whose interval contains the best AUROC
    for name in CFG["candidates"]:
        if dev.loc[name, "lo"] <= dev.loc[best, "auroc"] <= dev.loc[name, "hi"]:
            return {"selected": name, "best": best, "best_auroc": float(dev.loc[best, "auroc"]),
                    "best_interval": [float(lo), float(hi)], "rule": "simplest candidate whose 95% "
                    "interval contains the best development AUROC (primary outcome)"}
    return {"selected": best, "best": best}


def main():
    table = load_thresholds()
    dev = make_samples(_common.eicu_demo(), table)
    ext = make_samples(_common.douala(), table)
    st_dev = S.states(dev, CFG["current_hours"], tuple(CFG["baseline_hours"]))
    scales = S.Scales.fit(st_dev)                    # development only
    _, d_dev = frame(dev, table, scales)
    _, d_ext = frame(ext, table, scales)
    res = pd.DataFrame(evaluate(d_dev, "development") + evaluate(d_ext, "douala"))
    _common.OUT.mkdir(exist_ok=True)
    res.to_csv(_common.OUT / "state_comparison.csv", index=False)
    choice = select(res)
    choice["scales"] = scales.to_json()
    (_common.OUT / "state_comparison.json").write_text(json.dumps(choice, indent=1), encoding="utf8")
    # scales of the development data, read by the risk service (evolution block); no patient data
    art = _common.ROOT / "artifacts"
    art.mkdir(exist_ok=True)
    (art / "state_scales.json").write_text(json.dumps(scales.to_json(), indent=1), encoding="utf8")
    with pd.option_context("display.width", 140, "display.max_rows", 100):
        print(res.to_string(index=False))
    print(f"\nselected: {choice['selected']}  (best: {choice['best']})")
    print("Set `selected` and `status: selected` in configs/state_compare.yaml to use it in the risk service.")


if __name__ == "__main__":
    main()
