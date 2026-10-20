"""Nested benchmark — thesis ch.3 §Training protocol, §Metrics, §Candidate families.

For each task and lead time:
  outer folds (grouped by hospital) x repeats
    for each candidate family:
      Optuna TPE proposes configurations, each scored by pooled inner-fold
      predictions (folds grouped by patient); the search objective is the RPS;
      the configuration kept is the one with the lowest selection cost among
      the trials (configs/cost.yaml);
      it is refitted on the outer training set and evaluated once on the test fold.
    the selection procedure across families is itself nested: the family with
    the lowest inner selection cost is "selected", and its outer result is the
    estimate of the whole procedure.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

import numpy as np
import optuna
import pandas as pd
import yaml

from . import features as F
from . import metrics as M
from . import objective as O
from . import validation as V
from .labels import ThresholdTable
from .models import tabular as T
from .models.sequence import SequenceModel, build_sequences
from .progress import progress
from .windows import SampleSet

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BENCH = ROOT / "configs" / "benchmark.yaml"
PERSISTENCE_WINDOW = 96.0   # the last reading of each channel within four days

optuna.logging.set_verbosity(optuna.logging.WARNING)

TABULAR = {"ordinal_logistic", "pca_logistic", "forest", "catboost", "value_ridge", "value_catboost"}
SEQUENCE = {"grud", "lstm"}


def load_bench(path=DEFAULT_BENCH) -> dict:
    return yaml.safe_load(Path(path).read_text(encoding="utf8"))


# ---------------------------------------------------------------- inputs
class Inputs:
    """Feature matrices and sequences per window length, computed once."""

    def __init__(self, samples: SampleSet, feature_set: str):
        self.samples, self.feature_set = samples, feature_set
        self._tab, self._seq = {}, {}

    def tabular(self, L: float) -> pd.DataFrame:
        if L not in self._tab:
            self._tab[L] = F.compute(self.samples, L, self.feature_set)
        return self._tab[L]

    def persistence(self) -> pd.DataFrame:
        key = ("persistence", PERSISTENCE_WINDOW)
        if key not in self._tab:
            self._tab[key] = F.compute(self.samples, PERSISTENCE_WINDOW, "primary")
        return self._tab[key]

    def sequence(self, L: float):
        if L not in self._seq:
            self._seq[L] = build_sequences(self.samples, L)
        return self._seq[L]

    def values(self) -> pd.DataFrame:
        cols = ["v_sbp", "v_dbp", "v_hr", "v_glucose"]
        return self.samples.meta[cols].rename(columns=lambda c: c[2:])


def _take(X, idx):
    return X.iloc[idx] if isinstance(X, pd.DataFrame) else X.subset(idx)


# ---------------------------------------------------------------- candidates
def _suggest(trial: optuna.Trial, space: dict) -> dict:
    out = {}
    for group in ("structural", "training"):
        for name, spec in (space.get(group) or {}).items():
            if isinstance(spec, list) and spec and spec[0] in ("int", "float"):
                kind, lo, hi, log = spec
                fn = trial.suggest_int if kind == "int" else trial.suggest_float
                out[name] = fn(name, lo, hi, log=bool(log))
            else:
                choice = trial.suggest_categorical(name, [str(c) for c in spec])
                out[name] = next(c for c in spec if str(c) == choice)
    return out


def build(name: str, p: dict, table: ThresholdTable, task: str, seed: int):
    w = p.get("weights", "none")
    if name == "ordinal_logistic":
        return T.OrdinalLogistic(C=p["C"], weights=w)
    if name == "pca_logistic":
        return T.OrdinalLogistic(C=p["C"], n_components=p["n_components"], weights=w)
    if name == "forest":
        md = None if p["max_depth"] == "none" else int(p["max_depth"])
        mf = p["max_features"] if p["max_features"] == "sqrt" else float(p["max_features"])
        return T.Forest(params=dict(max_features=mf, min_samples_leaf=p["min_samples_leaf"], max_depth=md), weights=w, seed=seed)
    if name == "catboost":
        keys = ("depth", "iterations", "learning_rate", "l2_leaf_reg")
        return T.Boosting(params={k: p[k] for k in keys}, weights=w, seed=seed)
    if name == "value_ridge":
        return T.ValueForecast(table, task, "ridge", params={"alpha": p["alpha"]}, seed=seed)
    if name == "value_catboost":
        keys = ("depth", "iterations", "learning_rate", "l2_leaf_reg")
        return T.ValueForecast(table, task, "catboost", params={k: p[k] for k in keys}, seed=seed)
    if name in SEQUENCE:
        keys = ("hidden", "dropout", "lr", "weight_decay", "aux_weight")
        kw = {k: p[k] for k in keys}
        if name == "lstm":
            kw["layers"] = p["layers"]
        return SequenceModel(kind=name, weights=w, seed=seed, **kw)
    raise KeyError(name)


def _fit_predict(name, p, inputs: Inputs, table, task, y, groups, tr, te, seed):
    L = float(p["window"])
    X = inputs.sequence(L) if name in SEQUENCE else inputs.tabular(L)
    vals = inputs.values()
    model = build(name, p, table, task, seed)
    model.fit(_take(X, tr), y[tr], groups[tr], vals.iloc[tr])
    return model.predict_proba(_take(X, te))


def _inner_metrics(name, p, inputs, table, task, y, groups, rows, inner, seed, thresholds):
    proba = np.zeros((len(rows), 4))
    for tr, va in progress(inner, desc=f"    {name} inner folds", leave=False, unit="fold"):
        proba[va] = _fit_predict(name, p, inputs, table, task, y, groups, rows[tr], rows[va], seed)
    return M.evaluate(proba, y[rows], thresholds)


def search_candidate(name, inputs, table, task, y, groups, rows, bench, cost_cfg, seed):
    """Inner search on `rows`.

    Returns (best params, its inner measures, number of trials, table of every
    trial with its parameters, inner measures, selection cost and whether it was kept)."""
    space = {"structural": {**bench["spaces"]["common"]["structural"], **(bench["spaces"][name].get("structural") or {})},
             "training": {**bench["spaces"]["common"]["training"], **(bench["spaces"][name].get("training") or {})}}
    if name in {"value_ridge", "value_catboost"}:
        space["training"].pop("weights", None)        # regression: no class weights
    ev = (y[rows] >= M.ALERT_LEVEL).astype(int)
    inner = V.inner_splits(ev, groups[rows], bench["validation"]["inner_folds"], seed)
    ths = cost_cfg["net_benefit_thresholds"]
    trials = []

    def objective(trial):
        p = _suggest(trial, space)
        m = _inner_metrics(name, p, inputs, table, task, y, groups, rows, inner, seed, ths)
        trials.append((p, m))
        return m["rps"]

    study = optuna.create_study(direction="minimize", sampler=optuna.samplers.TPESampler(seed=seed))
    n_trials = bench["search"]["trials"][name]
    with progress(desc=f"   {name} trials", total=n_trials, leave=False, unit="trial") as bar:
        study.optimize(objective, n_trials=n_trials, callbacks=[lambda study, trial: bar.update(1)])
    res = pd.DataFrame([m for _, m in trials])
    cost = O.selection_cost(res, cost_cfg).fillna(np.inf)
    best = int(cost.idxmin()) if np.isfinite(cost).any() else int(res["rps"].idxmin())
    table_ = res.assign(candidate=name, trial=range(len(trials)), params=[json.dumps(p) for p, _ in trials],
                        selection_cost=cost.to_numpy(), kept=[i == best for i in range(len(trials))])
    return trials[best][0], trials[best][1], len(trials), table_


def run(samples: SampleSet, sites: np.ndarray, table: ThresholdTable, task: str,
        candidates: list[str], bench: dict | None = None, cost_cfg: dict | None = None,
        out: Path | None = None, resume: bool = True, recorder=None) -> pd.DataFrame:
    """Nested benchmark of the candidates on one dataset, task and lead time.

    With `resume`, folds already complete in `out` (all candidates and the
    `selected` row present) are kept and skipped: the fold assignment is
    deterministic, and each kept fold is checked against the current split.
    With a `recorder` (tracking.Run), folds, trials and outer predictions are
    saved in the run folder, and resuming reads from it."""
    bench = bench or load_bench()
    cost_cfg = cost_cfg or O.load_cost()
    label = T.TASKS[task]["label"]
    meta = samples.meta
    rows_all = np.flatnonzero(meta[label].notna().to_numpy())
    y = np.full(len(meta), -1)
    y[rows_all] = meta[label].to_numpy()[rows_all].astype(int)
    groups = meta["group"].to_numpy()
    inputs = Inputs(samples, bench["feature_set"])
    ths = cost_cfg["net_benefit_thresholds"]
    v = bench["validation"]
    records, done = [], {}
    prev = recorder.table("folds.csv") if recorder is not None else (
        pd.read_csv(out) if out is not None and Path(out).exists() else None)
    if resume and prev is not None:
        for key, g in prev.groupby(["repeat", "fold"]):
            if {"selected", "prior", "persistence", *candidates} <= set(g.candidate):
                done[key] = g
    ev = (y[rows_all] >= M.ALERT_LEVEL).astype(int)
    splits = list(V.outer_splits(ev, sites[rows_all], v["outer_folds"], v["repeats"], v["seed"]))
    for split in progress(splits, desc=f"{task} outer folds", unit="fold"):
        tr, te = rows_all[split.train], rows_all[split.test]
        key = (split.repeat, split.fold)
        if key in done:
            g = done[key]
            if int(g.n_test.iloc[0]) != len(te):
                raise RuntimeError(f"fold {key} in {out} does not match the current split; delete the file to restart")
            records.extend(g.to_dict("records"))
            _log(f"{task} repeat {split.repeat} fold {split.fold}: kept from previous run")
            continue
        seed = v["seed"] + 100 * split.repeat + split.fold
        fold_records, fold_trials = [], []
        where = f"predictions/outer/r{split.repeat}_f{split.fold}"

        def keep(name, proba):
            if recorder is not None:
                recorder.save_predictions(f"{where}/{name}.npz", sample=te, patient=meta.patient.to_numpy()[te],
                                          group=groups[te], y=y[te], proba=proba)
        base = dict(task=task, lead_h=float(meta.lead_h.iloc[0]), repeat=split.repeat, fold=split.fold,
                    n_train=len(tr), n_test=len(te), patients_test=len(np.unique(groups[te])))
        Xp = inputs.persistence()
        for name, model in (("prior", T.Prior()), ("persistence", T.Persistence(table, task))):
            model.fit(Xp.iloc[tr], y[tr])
            proba = model.predict_proba(Xp.iloc[te])
            keep(name, proba)
            fold_records.append({**base, "candidate": name, **M.evaluate(proba, y[te], ths)})
        inner_best = {}
        for name in progress(candidates, desc=f"  fold {split.repeat}.{split.fold} candidates", leave=False,
                             unit="model"):
            t0 = time.time()
            p, inner_m, n_trials, trials = search_candidate(name, inputs, table, task, y, groups, tr, bench,
                                                            cost_cfg, seed)
            proba = _fit_predict(name, p, inputs, table, task, y, groups, tr, te, seed)
            keep(name, proba)
            outer_m = M.evaluate(proba, y[te], ths)
            inner_best[name] = inner_m
            fold_trials.extend(trials.assign(repeat=split.repeat, fold=split.fold).to_dict("records"))
            fold_records.append({**base, "candidate": name, "params": json.dumps(p), "n_trials": n_trials,
                                 "seconds": round(time.time() - t0, 1), **outer_m})
            _log(f"{task} repeat {split.repeat} fold {split.fold}: {name} done in {time.time() - t0:.0f} s "
                 f"(outer RPS {outer_m['rps']:.4f})")
        if inner_best:
            chosen = O.selection_cost(pd.DataFrame(inner_best).T, cost_cfg).idxmin()
            outer_chosen = next(r for r in fold_records if r["candidate"] == chosen)
            fold_records.append({**{k: v_ for k, v_ in outer_chosen.items() if k not in ("candidate", "params")},
                                 "candidate": "selected", "params": json.dumps({"family": chosen})})
        records.extend(fold_records)
        if recorder is not None:                # a fold is written only when complete
            recorder.add_trials(fold_trials)
            recorder.add_fold_rows(fold_records)
            recorder.progress(folds_done=len({(r["repeat"], r["fold"]) for r in records}), folds_total=len(splits))
        if out:
            pd.DataFrame(records).to_csv(out, index=False)
    return pd.DataFrame(records)


LOG_FILE: Path | None = None       # set to the run folder's run.log by run.py


def _log(msg: str) -> None:
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}"
    # above the progress bars, which tqdm then redraws
    from tqdm import tqdm
    tqdm.write(line)
    if LOG_FILE is not None:
        with open(LOG_FILE, "a", encoding="utf8") as f:
            f.write(line + "\n")


def compare(results: pd.DataFrame, a: str, b: str, metric: str = "rps") -> dict:
    """Corrected resampled t test of candidate a against b on the same folds."""
    ra = results[results.candidate == a].set_index(["repeat", "fold"])
    rb = results[results.candidate == b].set_index(["repeat", "fold"])
    j = ra.join(rb, lsuffix="_a", rsuffix="_b", how="inner")
    d = (j[f"{metric}_a"] - j[f"{metric}_b"]).to_numpy()
    t, p = V.corrected_ttest(d, j["n_train_a"].mean(), j["n_test_a"].mean())
    return {"a": a, "b": b, "metric": metric, "mean_diff": float(np.mean(d)), "t": t, "p": p, "k": len(d)}
