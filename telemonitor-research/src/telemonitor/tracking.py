"""Run records: everything needed to retrace a benchmark and redraw its figures.

A run is identified by what determines its results — task, lead time, candidate
list, the effective configurations (thresholds, selection cost, benchmark
protocol) and the fingerprints of the data. Launching an identical run resumes
it in the same folder; changing a configuration or the data starts a new one.
Each launch (session) is logged with the code version, a copy of the code, the
Python environment and the git state.

Folder  out/runs/<task>_<lead>h[_quick]_<id>/
  manifest.json        identity, inputs, sessions, environment, progress, status
  config/              the effective configurations, as used
  code/<hash>/         copy of src/telemonitor and scripts/ for each code version used
  folds.csv            outer-fold results, one row per fold and candidate
  trials.csv           every hyperparameter trial: fold, candidate, parameters, inner measures, cost
  predictions/outer/   r<repeat>_f<fold>/<candidate>.npz: sample index, patient, group, y, probabilities
  external/            <candidate>.npz (Douala predictions), external.csv, models/<candidate>.joblib
  summary.json         means and corrected tests, written at the end
Files are written atomically, so an interrupted run never leaves a half-written file.
"""
from __future__ import annotations

import atexit
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from importlib import metadata
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parents[2]
PACKAGES = ("numpy", "pandas", "scipy", "scikit-learn", "catboost", "optuna", "torch", "xgboost", "PyYAML", "tqdm")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _hash_obj(obj) -> str:
    return hashlib.sha256(json.dumps(obj, sort_keys=True, default=str).encode()).hexdigest()


def code_hash() -> str:
    h = hashlib.sha256()
    for p in sorted((ROOT / "src" / "telemonitor").rglob("*.py")):
        h.update(p.relative_to(ROOT).as_posix().encode())
        h.update(p.read_bytes())
    return h.hexdigest()[:12]


def _git() -> dict:
    def run(*args):
        try:
            return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, timeout=20).stdout.strip()
        except Exception:
            return ""
    return {"commit": run("rev-parse", "HEAD"), "dirty": run("status", "--porcelain", "--", ".").splitlines()}


def environment() -> dict:
    pk = {}
    for name in PACKAGES:
        try:
            pk[name] = metadata.version(name)
        except metadata.PackageNotFoundError:
            pk[name] = None
    return {"python": sys.version.split()[0], "platform": platform.platform(), "cpus": os.cpu_count(),
            "packages": pk, "in_docker": Path("/.dockerenv").exists()}


def _pid_alive(pid: int) -> bool:
    """Whether a process with this id is running (Windows and POSIX)."""
    if pid <= 0:
        return False
    if os.name == "nt":
        import ctypes
        k = ctypes.windll.kernel32
        h = k.OpenProcess(0x1000, False, pid)            # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        code = ctypes.c_ulong()
        ok = k.GetExitCodeProcess(h, ctypes.byref(code))
        k.CloseHandle(h)
        return bool(ok) and code.value == 259            # STILL_ACTIVE
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


class RunLocked(RuntimeError):
    pass


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


class Run:
    def __init__(self, task: str, lead_h: float, candidates: list[str], bench: dict, cost: dict,
                 thresholds_path: Path, data_files: dict[str, Path], quick: bool = False,
                 root: Path | None = None):
        inputs = {
            "task": task, "lead_h": float(lead_h), "quick": quick, "candidates": list(candidates),
            "benchmark": bench, "cost": cost,
            "thresholds_sha256": sha256_file(thresholds_path),
            "data_sha256": {k: sha256_file(p) for k, p in data_files.items()},
        }
        self.run_id = f"{task}_{int(lead_h)}h{'_quick' if quick else ''}_{_hash_obj(inputs)[:10]}"
        self.dir = (root or ROOT / "out") / "runs" / self.run_id
        self.manifest_path = self.dir / "manifest.json"
        self._lock(self.dir / "run.lock")
        new = not self.manifest_path.exists()
        if new:
            self.dir.mkdir(parents=True, exist_ok=True)
            cfg = self.dir / "config"
            cfg.mkdir(exist_ok=True)
            shutil.copy2(thresholds_path, cfg / "thresholds.yaml")
            (cfg / "benchmark.yaml").write_text(yaml.safe_dump(bench, sort_keys=False), encoding="utf8")
            (cfg / "cost.yaml").write_text(yaml.safe_dump(cost, sort_keys=False), encoding="utf8")
            self.manifest = {"run_id": self.run_id, "created": time.strftime("%Y-%m-%d %H:%M:%S"),
                             "status": "running", "inputs": inputs, "data_files": {k: str(p) for k, p in data_files.items()},
                             "sessions": [], "progress": {}}
        else:
            self.manifest = json.loads(self.manifest_path.read_text(encoding="utf8"))
        ch = code_hash()
        code_dir = self.dir / "code" / ch
        if not code_dir.exists():
            shutil.copytree(ROOT / "src" / "telemonitor", code_dir / "telemonitor",
                            ignore=shutil.ignore_patterns("__pycache__"))
            if (ROOT / "scripts").exists():
                shutil.copytree(ROOT / "scripts", code_dir / "scripts", ignore=shutil.ignore_patterns("__pycache__"))
        self.manifest["sessions"].append({"started": time.strftime("%Y-%m-%d %H:%M:%S"), "code_hash": ch,
                                          "git": _git(), "environment": environment(), "argv": sys.argv})
        self.manifest["status"] = "running"
        self._save_manifest()

    # ------------------------------------------------------------ lock
    def _lock(self, lock: Path) -> None:
        """One process per run: a second launch of the same run is refused while the first is alive."""
        lock.parent.mkdir(parents=True, exist_ok=True)
        if lock.exists():
            try:
                pid = int(lock.read_text().split()[0])
            except (ValueError, IndexError):
                pid = -1
            if pid != os.getpid() and _pid_alive(pid):
                raise RunLocked(f"run {self.run_id} is already running (process {pid}); "
                                f"stop it first or wait for it to finish")
        lock.write_text(f"{os.getpid()} {time.strftime('%Y-%m-%d %H:%M:%S')}")
        self._lock_path = lock
        atexit.register(self.release)

    def release(self) -> None:
        try:
            if self._lock_path.exists() and self._lock_path.read_text().split()[0] == str(os.getpid()):
                self._lock_path.unlink()
        except OSError:
            pass

    @property
    def log_path(self) -> Path:
        return self.dir / "run.log"

    # ------------------------------------------------------------ manifest
    def _save_manifest(self) -> None:
        _atomic_write(self.manifest_path, json.dumps(self.manifest, indent=1, default=str).encode("utf8"))

    def progress(self, **fields) -> None:
        self.manifest["progress"].update(fields, updated=time.strftime("%Y-%m-%d %H:%M:%S"))
        self._save_manifest()

    def finish(self, summary: dict) -> None:
        _atomic_write(self.dir / "summary.json", json.dumps(summary, indent=1, default=str).encode("utf8"))
        self.manifest["status"] = "complete"
        self.manifest["finished"] = time.strftime("%Y-%m-%d %H:%M:%S")
        self._save_manifest()
        self.release()

    # ------------------------------------------------------------ tables
    def _append(self, name: str, rows: list[dict]) -> None:
        path = self.dir / name
        old = pd.read_csv(path) if path.exists() else None
        new = pd.DataFrame(rows)
        df = new if old is None else pd.concat([old, new], ignore_index=True)
        _atomic_write(path, df.to_csv(index=False).encode("utf8"))

    def table(self, name: str) -> pd.DataFrame | None:
        path = self.dir / name
        return pd.read_csv(path) if path.exists() else None

    def add_fold_rows(self, rows: list[dict]) -> None:
        self._append("folds.csv", rows)

    def add_trials(self, rows: list[dict]) -> None:
        self._append("trials.csv", rows)

    def add_external_row(self, row: dict) -> None:
        self._append("external/external.csv", [row])

    # ------------------------------------------------------------ predictions and models
    def save_predictions(self, relpath: str, **arrays) -> None:
        path = self.dir / relpath
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.stem + ".tmp.npz")
        np.savez_compressed(tmp, **{k: np.asarray(v) for k, v in arrays.items()})
        os.replace(tmp, path)

    def save_model(self, name: str, model, params: dict) -> None:
        import joblib
        path = self.dir / "external" / "models" / f"{name}.joblib"
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        joblib.dump(model, tmp)
        os.replace(tmp, path)
        _atomic_write(path.with_suffix(".params.json"), json.dumps(params, indent=1).encode("utf8"))
