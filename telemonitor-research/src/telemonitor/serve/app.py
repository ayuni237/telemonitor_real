"""Local risk service.

    uvicorn telemonitor.serve.app:app --app-dir src        (artifacts in ./artifacts/<task>/)

POST /v1/risk with the patient's recent readings (no identifier) returns, per
condition, the probabilities of the four levels and the alert probability; the
tier of the guideline rule applied to the last readings; and the final tier,
max(rule, model), since the model may raise the rule's tier but never lower it.
The same Python code as the research pipeline computes features and labels, so
the service and the benchmark cannot drift apart.
"""
from __future__ import annotations

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Literal, Optional

import numpy as np
import pandas as pd
import yaml
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .. import features as F
from .. import quality as Q
from .. import state as ST
from ..labels import load_thresholds
from ..metrics import alert_probability
from ..models.sequence import build_sequences
from ..search import PERSISTENCE_WINDOW
from ..windows import SampleSet
from . import artifact

ROOT = Path(__file__).resolve().parents[3]
SERVE_CFG = yaml.safe_load((ROOT / "configs" / "serve.yaml").read_text(encoding="utf8"))
TIERS = ["green", "yellow", "red"]
TASKS = ("haemodynamic", "glycaemic")


class Reading(BaseModel):
    time: datetime
    sbp: Optional[float] = Field(None, description="mmHg")
    dbp: Optional[float] = Field(None, description="mmHg")
    hr: Optional[float] = Field(None, description="beats per minute")
    glucose: Optional[float] = Field(None, description="capillary glucose, mmol/L")


class RiskRequest(BaseModel):
    readings: list[Reading] = Field(..., min_length=1, max_length=500)
    age: Optional[float] = Field(None, ge=0, le=120)
    sex: Optional[Literal["M", "F"]] = None


def _tier_of_probability(p: float) -> str:
    t = SERVE_CFG["tiers"]
    return "red" if p >= t["red"] else "yellow" if p >= t["yellow"] else "green"


def _worst(*tiers: str) -> str:
    return TIERS[max(TIERS.index(t) for t in tiers)]


def load_artifacts(folder: Path) -> dict:
    found = {}
    for task in TASKS:
        if (folder / task / "manifest.json").exists():
            found[task] = artifact.load(folder / task)
    return found


def readings_frame(req: RiskRequest) -> pd.DataFrame:
    """Readings with time `t` in hours, impossible values removed as in the research pipeline."""
    rows = sorted(req.readings, key=lambda r: r.time)
    t0 = rows[0].time
    df = pd.DataFrame([{"t": (r.time - t0).total_seconds() / 3600, "sbp": r.sbp, "dbp": r.dbp,
                        "hr": r.hr, "glucose": r.glucose} for r in rows], dtype=float)
    for ch, (lo, hi) in Q.PLAUSIBLE.items():
        df.loc[~df[ch].between(lo, hi), ch] = np.nan
    bad = (df.sbp <= df.dbp) | (df.sbp - df.dbp < Q.MIN_PULSE_PRESSURE)
    df.loc[bad.fillna(False), ["sbp", "dbp"]] = np.nan
    return df.assign(patient=0, group=0, age=req.age, sex=req.sex)


def anchor_sample(df: pd.DataFrame) -> SampleSet:
    meta = pd.DataFrame({"patient": [0], "group": [0], "anchor": [len(df) - 1], "target": [-1], "lead_h": [0.0]})
    return SampleSet(df.reset_index(drop=True), meta, 0.0)


class NoPlausibleReading(ValueError):
    pass


def assess(req: RiskRequest, table, arts: dict, evo: tuple | None = None) -> dict:
    """Rule floor and model tiers for one patient's recent readings; shared by
    the endpoint and the worker (worker.py), so both score identically.

    With `evo` = (scales, measure), also the evolution of the patient's state
    (state.evolution): current 24 h against the previous three days."""
    df = readings_frame(req)
    if df[["sbp", "dbp", "hr", "glucose"]].isna().all().all():
        raise NoPlausibleReading("no plausible reading")
    s = anchor_sample(df)
    # guideline floor: the rule applied to the last value of each channel within four days
    recent = df[df.t > df.t.iloc[-1] - PERSISTENCE_WINDOW]
    last = recent[["sbp", "dbp", "hr", "glucose"]].ffill().iloc[[-1]]
    rule_level = table.label(last)["y"].iloc[0]
    rule_tier = SERVE_CFG["rule_floor"][int(rule_level)] if np.isfinite(rule_level) else "green"
    out = {"threshold_version": table.version, "thresholds_status": SERVE_CFG["status"],
           "rule": {"level": None if not np.isfinite(rule_level) else int(rule_level), "tier": rule_tier},
           "conditions": {}}
    tiers = [rule_tier]
    for task, a in arts.items():
        m = a.manifest
        X = build_sequences(s, m["window_hours"]) if m["input"] == "sequence" else \
            F.compute(s, m["window_hours"], m["feature_set"])
        proba = a.model.predict_proba(X)[0]
        p_alert = float(alert_probability(proba[None, :])[0])
        tier = _tier_of_probability(p_alert)
        tiers.append(tier)
        out["conditions"][task] = {"model": a.version, "probabilities": [round(float(x), 4) for x in proba],
                                   "alert_probability": round(p_alert, 4), "tier": tier}
    out["tier"] = _worst(*tiers)
    if evo is not None:
        scales, measure = evo
        out["evolution"] = ST.evolution(df.t.to_numpy(), {c: df[c].to_numpy() for c in ST.CHANNELS}, scales, measure)
    return out


def load_evolution(folder: Path) -> tuple | None:
    """Development scales (scripts/12_state_comparison.py) and the measure
    selected by that benchmark (configs/state_compare.yaml); None before the
    benchmark has been run."""
    path = folder / "state_scales.json"
    if not path.exists():
        return None
    cfg = yaml.safe_load((ROOT / "configs" / "state_compare.yaml").read_text(encoding="utf8"))
    measure = cfg.get("selected") if cfg.get("status") == "selected" else None
    return ST.Scales.from_json(json.loads(path.read_text(encoding="utf8"))), measure


def load_checked(artifacts_dir: Path | None = None):
    """Threshold table and artifacts; refuses an artifact labelled with another threshold version."""
    folder = Path(artifacts_dir or os.environ.get("TELEMONITOR_ARTIFACTS", ROOT / "artifacts"))
    table = load_thresholds()
    arts = load_artifacts(folder)
    for task, a in arts.items():
        if a.manifest["threshold_version"] != table.version:
            raise RuntimeError(f"{task}: artifact labelled with thresholds {a.manifest['threshold_version']}, "
                               f"service uses {table.version}")
    return table, arts


def create_app(artifacts_dir: Path | None = None) -> FastAPI:
    table, arts = load_checked(artifacts_dir)
    evo = load_evolution(Path(artifacts_dir or os.environ.get("TELEMONITOR_ARTIFACTS", ROOT / "artifacts")))
    app = FastAPI(title="TeleMonitor risk service", version="0.2.0")
    # the Flutter web build calls the service from another origin
    origins = [o for o in os.environ.get("TELEMONITOR_CORS", "").split(",") if o]
    if origins:
        app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["GET", "POST"],
                           allow_headers=["Content-Type"])

    @app.get("/health")
    def health():
        return {"status": "ok", "threshold_version": table.version, "thresholds_status": SERVE_CFG["status"],
                "models": {t: a.version for t, a in arts.items()}}

    @app.post("/v1/risk")
    def risk(req: RiskRequest):
        try:
            return assess(req, table, arts, evo)
        except NoPlausibleReading as e:
            raise HTTPException(422, str(e))

    return app


app = create_app() if os.environ.get("TELEMONITOR_SERVE", "1") == "1" else None
