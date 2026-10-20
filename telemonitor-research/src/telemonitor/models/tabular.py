"""Tabular candidates (one feature vector per sample).

Families and their justification are in the thesis (§Candidate families):
prior and persistence baselines; penalised proportional-odds logistic
regression, optionally on principal components; random forest; CatBoost; and
the value-forecast formulation with a ridge or CatBoost regressor per channel.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.special import expit
from sklearn.decomposition import PCA
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import Ridge
from sklearn.model_selection import GroupKFold

from ..labels import ThresholdTable
from .levels import N_LEVELS, channel_level_proba, condition_level_proba

# Task: label column and the channels (data column -> threshold-table channel).
TASKS = {
    "haemodynamic": {"label": "y_haemodynamic", "channels": {"sbp": "sbp", "dbp": "dbp", "hr": "pulse"}},
    "glycaemic": {"label": "y_glycaemic", "channels": {"glucose": "glucose"}},
}


# ---------------------------------------------------------------- utilities
def class_weights(y: np.ndarray, scheme: str) -> np.ndarray:
    """Per-class weights: 'none' or 'balanced' (n / (K * n_k)); absent classes get 1."""
    if scheme == "none":
        return np.ones(N_LEVELS)
    counts = np.bincount(np.asarray(y, int), minlength=N_LEVELS).astype(float)
    w = np.where(counts > 0, counts.sum() / (N_LEVELS * np.maximum(counts, 1)), 1.0)
    return w


def undo_class_weights(proba: np.ndarray, w: np.ndarray) -> np.ndarray:
    """Exact correction of the probabilities of a model trained with class
    weights: dividing by the weight restores the training priors (Bayes rule)."""
    p = proba / w[None, :]
    return p / p.sum(axis=1, keepdims=True)


def full_proba(model_classes, proba: np.ndarray) -> np.ndarray:
    """Probabilities on all four levels, even when some level was absent in training."""
    out = np.zeros((proba.shape[0], N_LEVELS))
    out[:, np.asarray(model_classes, int)] = proba
    return out


@dataclass
class Preprocessor:
    """Median imputation with missing indicators, then standardisation — fitted on training data."""
    medians: pd.Series = None
    indicator_cols: list = None
    mean: np.ndarray = None
    std: np.ndarray = None

    def fit(self, X: pd.DataFrame) -> "Preprocessor":
        self.medians = X.median()
        self.indicator_cols = [c for c in X.columns if X[c].isna().any()]
        Z = self._raw(X)
        self.mean, self.std = Z.mean(axis=0), Z.std(axis=0)
        self.std[self.std == 0] = 1.0
        return self

    def _raw(self, X: pd.DataFrame) -> np.ndarray:
        filled = X.fillna(self.medians).fillna(0.0)
        ind = X[self.indicator_cols].isna().astype(float)
        return np.column_stack([filled.to_numpy(float), ind.to_numpy(float)])

    def transform(self, X: pd.DataFrame) -> np.ndarray:
        return (self._raw(X) - self.mean) / self.std


# ---------------------------------------------------------------- baselines
@dataclass
class Prior:
    """Training frequencies of the levels, with add-one smoothing."""
    p: np.ndarray = None

    def fit(self, X, y, groups=None, values=None):
        self.p = (np.bincount(np.asarray(y, int), minlength=N_LEVELS) + 1.0)
        self.p /= self.p.sum()
        return self

    def predict_proba(self, X):
        return np.tile(self.p, (len(X), 1))


@dataclass
class Persistence:
    """Level of the last readings (the guideline rule applied to them), turned
    into probabilities by the transition matrix of the training data."""
    table: ThresholdTable
    task: str
    transition: np.ndarray = None
    prior: np.ndarray = None

    def _last_level(self, X: pd.DataFrame) -> np.ndarray:
        levels = []
        for col, ch in TASKS[self.task]["channels"].items():
            levels.append(self.table.channel_level(ch, X[f"{col}_last"].to_numpy(float)))
        return np.fmax.reduce(np.vstack(levels), axis=0)

    def fit(self, X, y, groups=None, values=None):
        last = self._last_level(X)
        y = np.asarray(y, int)
        T = np.ones((N_LEVELS, N_LEVELS))
        ok = ~np.isnan(last)
        np.add.at(T, (last[ok].astype(int), y[ok]), 1.0)
        self.transition = T / T.sum(axis=1, keepdims=True)
        self.prior = Prior().fit(None, y).p
        return self

    def predict_proba(self, X):
        last = self._last_level(X)
        out = np.tile(self.prior, (len(X), 1))
        ok = ~np.isnan(last)
        out[ok] = self.transition[last[ok].astype(int)]
        return out


# ---------------------------------------------------------------- linear
@dataclass
class OrdinalLogistic:
    """Proportional-odds model (McCullagh 1980) with an L2 penalty,
    P(y <= k | x) = sigmoid(theta_k - x beta), optionally on k principal components."""
    C: float = 1.0
    n_components: int | None = None
    weights: str = "none"
    prep: Preprocessor = field(default_factory=Preprocessor)
    pca: PCA | None = None
    beta: np.ndarray = None
    theta: np.ndarray = None
    w: np.ndarray = None

    def _design(self, X, fit=False):
        Z = self.prep.fit(X).transform(X) if fit else self.prep.transform(X)
        if self.n_components:
            if fit:
                k = min(self.n_components, Z.shape[1], Z.shape[0] - 1)
                self.pca = PCA(n_components=k).fit(Z)
            Z = self.pca.transform(Z)
        return Z

    @staticmethod
    def _cum(theta_raw):
        return np.concatenate([[theta_raw[0]], theta_raw[0] + np.cumsum(np.exp(theta_raw[1:]))])

    def _proba(self, Z, beta, theta):
        eta = Z @ beta
        cdf = expit(theta[None, :] - eta[:, None])
        cdf = np.column_stack([np.zeros(len(Z)), cdf, np.ones(len(Z))])
        return np.clip(np.diff(cdf, axis=1), 1e-12, 1)

    def fit(self, X, y, groups=None, values=None):
        Z = self._design(X, fit=True)
        y = np.asarray(y, int)
        self.w = class_weights(y, self.weights)
        sw = self.w[y]
        p = Z.shape[1]
        lam = 1.0 / (self.C * len(y))

        def nll(params):
            beta, theta = params[:p], self._cum(params[p:])
            P = self._proba(Z, beta, theta)
            return -np.sum(sw * np.log(P[np.arange(len(y)), y])) / sw.sum() + lam * np.sum(beta ** 2) / 2

        x0 = np.concatenate([np.zeros(p), [-1.0, 0.0, 0.0]])
        res = minimize(nll, x0, method="L-BFGS-B")
        self.beta, self.theta = res.x[:p], self._cum(res.x[p:])
        return self

    def predict_proba(self, X):
        P = self._proba(self._design(X), self.beta, self.theta)
        return undo_class_weights(P / P.sum(axis=1, keepdims=True), self.w)


# ---------------------------------------------------------------- trees
@dataclass
class Forest:
    """Random forest (Breiman 2001); scikit-learn handles missing values natively."""
    params: dict = field(default_factory=dict)
    weights: str = "none"
    seed: int = 0
    model: RandomForestClassifier = None
    w: np.ndarray = None

    def fit(self, X, y, groups=None, values=None):
        y = np.asarray(y, int)
        self.w = class_weights(y, self.weights)
        self.model = RandomForestClassifier(n_estimators=500, random_state=self.seed, n_jobs=-1, **self.params)
        self.model.fit(X.to_numpy(float), y, sample_weight=self.w[y])
        return self

    def predict_proba(self, X):
        P = full_proba(self.model.classes_, self.model.predict_proba(X.to_numpy(float)))
        return undo_class_weights(P + 1e-12, self.w)


@dataclass
class Boosting:
    """CatBoost multiclass (Prokhorenkova et al. 2018); missing values handled natively."""
    params: dict = field(default_factory=dict)
    weights: str = "none"
    seed: int = 0
    model: object = None
    w: np.ndarray = None

    def fit(self, X, y, groups=None, values=None):
        from catboost import CatBoostClassifier
        y = np.asarray(y, int)
        self.w = class_weights(y, self.weights)
        self.model = CatBoostClassifier(loss_function="MultiClass", random_seed=self.seed, verbose=False,
                                        thread_count=-1, allow_writing_files=False, **self.params)
        self.model.fit(X.to_numpy(float), y, sample_weight=self.w[y])
        return self

    def predict_proba(self, X):
        P = full_proba(self.model.classes_, self.model.predict_proba(X.to_numpy(float)))
        return undo_class_weights(P + 1e-12, self.w)


# ---------------------------------------------------------------- value forecast
@dataclass
class _Constant:
    value: float

    def predict(self, Z):
        return np.full(len(Z), self.value)


@dataclass
class ValueForecast:
    """Forecast each channel value, then integrate its error distribution over
    the threshold table. The error spread is estimated out of fold on the
    training data, so it reflects generalisation rather than fit."""
    table: ThresholdTable
    task: str
    regressor: str = "ridge"          # "ridge" or "catboost"
    params: dict = field(default_factory=dict)
    seed: int = 0
    models: dict = field(default_factory=dict)
    sigma: dict = field(default_factory=dict)
    prep: Preprocessor = None

    def _fit_one(self, Z, t):
        if np.ptp(t) == 0:                       # constant target: nothing to learn
            return _Constant(float(t[0]))
        return self._make().fit(Z, t)

    def _make(self):
        if self.regressor == "ridge":
            return Ridge(alpha=self.params.get("alpha", 1.0))
        from catboost import CatBoostRegressor
        return CatBoostRegressor(loss_function="RMSE", random_seed=self.seed, verbose=False,
                                 thread_count=-1, allow_writing_files=False, **self.params)

    def _X(self, X, fit=False):
        if self.regressor != "ridge":
            return X.to_numpy(float)
        if fit:
            self.prep = Preprocessor().fit(X)
        return self.prep.transform(X)

    def fit(self, X, y, groups, values: pd.DataFrame):
        Z = self._X(X, fit=True)
        groups = np.asarray(groups)
        for col in TASKS[self.task]["channels"]:
            t = values[col].to_numpy(float)
            ok = ~np.isnan(t)
            if not ok.any():                     # channel never observed at a target: no forecast
                self.models[col] = None
                continue
            oof = np.full(len(t), np.nan)
            k = min(3, len(np.unique(groups[ok])))
            if k >= 2:
                for tr, va in GroupKFold(n_splits=k).split(Z[ok], t[ok], groups[ok]):
                    m = self._fit_one(Z[ok][tr], t[ok][tr])
                    oof[np.flatnonzero(ok)[va]] = m.predict(Z[ok][va])
            resid = (t - oof)[ok]
            resid = resid[~np.isnan(resid)]
            self.sigma[col] = float(np.sqrt(np.mean(resid ** 2))) if len(resid) else float(np.nanstd(t))
            self.models[col] = self._fit_one(Z[ok], t[ok])
        return self

    def predict_proba(self, X):
        Z = self._X(X)
        per = [channel_level_proba(self.table, ch, self.models[col].predict(Z), self.sigma[col])
               for col, ch in TASKS[self.task]["channels"].items() if self.models.get(col) is not None]
        if not per:
            raise ValueError("no channel of the task was observed at any training target")
        P = condition_level_proba(per) + 1e-12
        return P / P.sum(axis=1, keepdims=True)
