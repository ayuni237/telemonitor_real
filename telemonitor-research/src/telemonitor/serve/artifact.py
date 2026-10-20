"""Versioned model artifacts.

An artifact is a folder with the fitted model (joblib) and a manifest stating
everything a prediction depends on: task, candidate, window length, feature
set, threshold-table version and a content hash. The service refuses an
artifact whose threshold version differs from the one it labels with.
"""
from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path

import joblib


@dataclass
class Artifact:
    model: object
    manifest: dict

    @property
    def version(self) -> str:
        return self.manifest["version"]


def save(model, folder: str | Path, *, task: str, candidate: str, window: float,
         feature_set: str, threshold_version: str, params: dict | None = None,
         development: str = "", metrics: dict | None = None) -> Artifact:
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "model.joblib"
    joblib.dump(model, path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()[:12]
    manifest = {"version": f"{task}-{candidate}-{digest}", "task": task, "candidate": candidate,
                "input": "sequence" if candidate in ("grud", "lstm") else "tabular",
                "window_hours": float(window), "feature_set": feature_set,
                "threshold_version": threshold_version, "params": params or {},
                "development": development, "metrics": metrics or {},
                "created": time.strftime("%Y-%m-%dT%H:%M:%S")}
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf8")
    return Artifact(model, manifest)


def load(folder: str | Path) -> Artifact:
    folder = Path(folder)
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf8"))
    path = folder / "model.joblib"
    digest = hashlib.sha256(path.read_bytes()).hexdigest()[:12]
    if not manifest["version"].endswith(digest):
        raise ValueError(f"artifact {folder} does not match its manifest (hash {digest})")
    return Artifact(joblib.load(path), manifest)
