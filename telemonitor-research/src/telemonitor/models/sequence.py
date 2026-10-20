"""Deep temporal candidates for H1 — masked LSTM and GRU-D (PyTorch).

Inputs are the raw readings of the window, oldest first, left-padded to a
common length: values (standardised on the training data), the mask of what was
measured, and the time since each channel was last measured. GRU-D (Che et al.
2018) decays a missing input from its last value towards the training mean, and
the hidden state towards zero, as the gap grows; the LSTM receives values,
mask and gaps as plain inputs (Hochreiter and Schmidhuber 1997).

Output head: cumulative logits for the four ordered levels, P(y > k) =
sigmoid(f(x) - b_k) with ordered biases, trained by ordinal negative
log-likelihood; an optional regression head forecasts the channel values at the
target (the dual-task formulation), its loss weighted by `aux_weight`.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import torch
from torch import nn

from ..progress import progress
from ..windows import SampleSet
from .levels import N_LEVELS
from .tabular import class_weights, undo_class_weights

CHANNELS = ("sbp", "dbp", "hr", "glucose")


@dataclass
class SeqInputs:
    values: np.ndarray   # (n, T, C) raw values, NaN where not measured
    gaps: np.ndarray     # (n, T, C) hours since the channel was last measured (0 at a measurement)
    steps: np.ndarray    # (n, T) 1 for a real reading, 0 for padding
    static: np.ndarray   # (n, 2) age, sex (1 = male), NaN if unknown

    def __len__(self):
        return len(self.values)

    def subset(self, idx) -> "SeqInputs":
        return SeqInputs(self.values[idx], self.gaps[idx], self.steps[idx], self.static[idx])


def build_sequences(samples: SampleSet, L: float) -> SeqInputs:
    data = samples.data
    T = int(L // 12) + 1
    n, C = len(samples), len(CHANNELS)
    vals = np.full((n, T, C), np.nan)
    gaps = np.zeros((n, T, C))
    steps = np.zeros((n, T))
    raw = data[list(CHANNELS)].to_numpy(float)
    t = data["t"].to_numpy(float)
    age = data["age"].to_numpy(float) if "age" in data else np.full(len(data), np.nan)
    sex = data["sex"].map({"M": 1.0, "F": 0.0}).to_numpy(float) if "sex" in data else np.full(len(data), np.nan)
    static = np.full((n, 2), np.nan)
    for k in progress(range(n), desc=f"sequences L={L:g}h", leave=False, unit="sample"):
        w = samples.window(k, L)[-T:]
        m = len(w)
        vals[k, T - m:] = raw[w]
        steps[k, T - m:] = 1
        last_seen = np.full(C, np.nan)
        for j, r in enumerate(w):
            obs = ~np.isnan(raw[r])
            last_seen[obs] = t[r]
            g = t[r] - last_seen
            gaps[k, T - m + j] = np.where(np.isnan(g), 0.0, g)
        a = samples.meta.anchor.iat[k]
        static[k] = (age[a], sex[a])
    return SeqInputs(vals, gaps, steps, static)


# ---------------------------------------------------------------- networks
class OrdinalHead(nn.Module):
    def __init__(self, d_in: int, n_aux: int):
        super().__init__()
        self.score = nn.Linear(d_in, 1)
        self.b0 = nn.Parameter(torch.zeros(1))
        self.db = nn.Parameter(torch.zeros(N_LEVELS - 2))
        self.aux = nn.Linear(d_in, n_aux)

    def forward(self, h):
        b = torch.cat([self.b0, self.b0 + torch.cumsum(nn.functional.softplus(self.db) + 1e-3, 0)])
        exceed = torch.sigmoid(self.score(h) - b[None, :])            # P(y > k), k = 0..2
        cdf = torch.cat([torch.ones_like(exceed[:, :1]), exceed, torch.zeros_like(exceed[:, :1])], 1)
        proba = (cdf[:, :-1] - cdf[:, 1:]).clamp_min(1e-7)
        return proba, self.aux(h)


class GRUDCell(nn.Module):
    """GRU-D cell: input and hidden decay driven by the time since last observation."""
    def __init__(self, n_in: int, hidden: int):
        super().__init__()
        self.gamma_x = nn.Linear(n_in, n_in)
        self.gamma_h = nn.Linear(n_in, hidden)
        self.cell = nn.GRUCell(2 * n_in, hidden)

    def forward(self, x, m, gap, x_last, x_mean, h):
        gx = torch.exp(-torch.relu(self.gamma_x(gap)))
        gh = torch.exp(-torch.relu(self.gamma_h(gap)))
        x_hat = m * x + (1 - m) * (gx * x_last + (1 - gx) * x_mean)
        return self.cell(torch.cat([x_hat, m], 1), gh * h)


class SequenceNet(nn.Module):
    def __init__(self, kind: str, n_ch: int, hidden: int, layers: int, dropout: float, n_static: int):
        super().__init__()
        self.kind = kind
        if kind == "grud":
            self.cell = GRUDCell(n_ch, hidden)
        else:
            self.rnn = nn.LSTM(3 * n_ch, hidden, num_layers=layers, batch_first=True,
                               dropout=dropout if layers > 1 else 0.0)
        self.drop = nn.Dropout(dropout)
        self.head = OrdinalHead(hidden + n_static, n_ch)

    def forward(self, x, m, gap, steps, static, x_mean):
        if self.kind == "grud":
            n, T, _ = x.shape
            h = x.new_zeros(n, self.cell.cell.hidden_size)
            x_last = x_mean.expand(n, -1).clone()
            for t in range(T):
                h_new = self.cell(x[:, t], m[:, t], gap[:, t], x_last, x_mean, h)
                live = steps[:, t:t + 1]
                h = live * h_new + (1 - live) * h
                x_last = torch.where(m[:, t] > 0, x[:, t], x_last)
        else:
            out, _ = self.rnn(torch.cat([x, m, gap], 2))
            h = out[:, -1]                                                # left padding: last step is real
        return self.head(torch.cat([self.drop(h), static], 1))


# ---------------------------------------------------------------- estimator
@dataclass
class SequenceModel:
    kind: str = "grud"             # "grud" or "lstm"
    hidden: int = 16
    layers: int = 1
    dropout: float = 0.2
    lr: float = 1e-2
    weight_decay: float = 1e-4
    aux_weight: float = 0.0        # weight of the value-regression head (dual task)
    weights: str = "none"
    max_epochs: int = 200
    patience: int = 15
    batch_size: int = 128
    seed: int = 0
    net: SequenceNet = None
    stats: dict = field(default_factory=dict)
    w: np.ndarray = None

    def _tensors(self, X: SeqInputs):
        mu, sd = self.stats["mu"], self.stats["sd"]
        x = (X.values - mu) / sd
        m = (~np.isnan(x)).astype(float)
        x = np.nan_to_num(x)
        gap = X.gaps / 24.0
        st = (X.static - self.stats["s_mu"]) / self.stats["s_sd"]
        st = np.nan_to_num(st)
        f = lambda a: torch.tensor(a, dtype=torch.float32)
        return f(x), f(m), f(gap), f(X.steps), f(st)

    def fit(self, X: SeqInputs, y, groups, values=None):
        torch.manual_seed(self.seed)
        rng = np.random.default_rng(self.seed)
        y = np.asarray(y, int)
        self.w = class_weights(y, self.weights)
        flat = X.values.reshape(-1, X.values.shape[2])
        mu, sd = np.nanmean(flat, 0), np.nanstd(flat, 0)
        mu, sd = np.nan_to_num(mu), np.where(np.nan_to_num(sd) > 0, sd, 1.0)
        s_mu, s_sd = np.nanmean(X.static, 0), np.nanstd(X.static, 0)
        self.stats = dict(mu=mu, sd=sd, s_mu=np.nan_to_num(s_mu), s_sd=np.where(np.nan_to_num(s_sd) > 0, s_sd, 1.0))
        aux = np.full((len(y), len(CHANNELS)), np.nan) if values is None else \
            (values[[f"{c}" for c in CHANNELS]].to_numpy(float) - mu) / sd

        # early stopping on a held-out 20% of training patients
        g = np.asarray(groups)
        ug = rng.permutation(np.unique(g))
        val_g = set(ug[: max(1, len(ug) // 5)])
        va = np.array([gi in val_g for gi in g])
        tr = ~va if va.any() and (~va).any() else np.ones(len(y), bool)

        x, m, gap, steps, st = self._tensors(X)
        x_mean = torch.zeros(1, x.shape[2])
        yt, wt = torch.tensor(y), torch.tensor(self.w[y], dtype=torch.float32)
        at = torch.tensor(aux, dtype=torch.float32)
        self.net = SequenceNet(self.kind, x.shape[2], self.hidden, self.layers, self.dropout, st.shape[1])
        opt = torch.optim.Adam(self.net.parameters(), lr=self.lr, weight_decay=self.weight_decay)

        def loss_on(idx):
            P, A = self.net(x[idx], m[idx], gap[idx], steps[idx], st[idx], x_mean)
            nll = -(wt[idx] * torch.log(P[torch.arange(len(idx)), yt[idx]])).sum() / wt[idx].sum()
            if self.aux_weight > 0:
                ok = ~torch.isnan(at[idx])
                if ok.any():
                    nll = nll + self.aux_weight * ((A - torch.nan_to_num(at[idx]))[ok] ** 2).mean()
            return nll

        tr_idx, va_idx = np.flatnonzero(tr), np.flatnonzero(va)
        best, best_state, wait = np.inf, None, 0
        bar = progress(desc=f"      {self.kind} epochs", total=self.max_epochs, leave=False, unit="epoch")
        for epoch in range(self.max_epochs):
            bar.update(1)
            self.net.train()
            for b in np.array_split(rng.permutation(tr_idx), max(1, len(tr_idx) // self.batch_size)):
                opt.zero_grad()
                loss_on(torch.tensor(b)).backward()
                opt.step()
            self.net.eval()
            with torch.no_grad():
                v = loss_on(torch.tensor(va_idx if len(va_idx) else tr_idx)).item()
            if v < best - 1e-4:
                best, wait = v, 0
                best_state = {k: t.clone() for k, t in self.net.state_dict().items()}
            else:
                wait += 1
                if wait >= self.patience:
                    break
        bar.close()
        self.net.load_state_dict(best_state)
        self.x_mean = x_mean
        return self

    def predict_proba(self, X: SeqInputs):
        self.net.eval()
        x, m, gap, steps, st = self._tensors(X)
        with torch.no_grad():
            P, _ = self.net(x, m, gap, steps, st, self.x_mean)
        P = P.numpy().astype(float)
        return undo_class_weights(P / P.sum(1, keepdims=True), self.w)

    def n_parameters(self) -> int:
        return sum(p.numel() for p in self.net.parameters())
