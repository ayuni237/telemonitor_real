"""Size of the relabelling sample — thesis ch.3 §Labelling.

How many Douala readings must the partner physician relabel so that the 95%
bootstrap confidence interval of the quadratically weighted kappa has a
half-width of at most 0.10?

The rule's levels are drawn from the observed distribution of the 366 readings;
a simulated physician disagrees with probability p, by one or two levels. With
p = 0.5 (kappa about 0.73) and p = 0.7 (kappa about 0.63) the half-width reaches
0.10 at about 100 and 150 readings respectively.

Usage: python scripts/09_kappa_sample_size.py [--reps 100] [--boot 500]
"""
import argparse

import numpy as np

import _common
from telemonitor.labels import load_thresholds

ap = argparse.ArgumentParser()
ap.add_argument("--reps", type=int, default=100)
ap.add_argument("--boot", type=int, default=500)
a = ap.parse_args()

y = load_thresholds().label(_common.douala())["y"].dropna().astype(int).to_numpy()
print("levels of the rule:", np.round(np.bincount(y, minlength=4) / len(y), 3), "readings:", len(y))

rng = np.random.default_rng(20261020)
W = np.subtract.outer(range(4), range(4)) ** 2 / 9


def qwk(a, b):
    """Quadratically weighted kappa of each row pair of a and b, shape (B, n)."""
    B, n = a.shape
    O = np.zeros((B, 4, 4))
    np.add.at(O, (np.repeat(np.arange(B), n), a.ravel(), b.ravel()), 1)
    E = O.sum(2)[:, :, None] * O.sum(1)[:, None, :] / n
    return 1 - (O * W).sum((1, 2)) / (E * W).sum((1, 2))


for p in (0.5, 0.7):
    for n in (30, 50, 75, 100, 150, 200):
        kappas, halfwidths = [], []
        for _ in range(a.reps):
            s = rng.choice(y, n)
            r = s.copy()
            f = rng.random(n) < p
            r[f] = np.clip(s[f] + rng.choice([-2, -1, 1, 2], f.sum()), 0, 3)
            i = rng.integers(0, n, (a.boot, n))
            b = qwk(s[i], r[i])
            kappas.append(qwk(s[None], r[None])[0])
            halfwidths.append((np.nanpercentile(b, 97.5) - np.nanpercentile(b, 2.5)) / 2)
        print(f"p={p}  n={n:3d}  kappa={np.median(kappas):.2f}  CI half-width={np.median(halfwidths):.3f}")
