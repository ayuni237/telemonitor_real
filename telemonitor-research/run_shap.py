"""SHAP analysis of the calibrated risk model.

Replaces gain-based importance, which is biased toward high-cardinality
features and unreliable under correlation -- both of which apply here,
since sbp and dbp correlate at r = 0.767 in the measured cohort.
"""
import numpy as np, pandas as pd, shap, json
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from gen import generate
from features import make_windows
from train import fit_full

LEVELS = ["Stable", "Moderate", "High", "Critical"]

df = generate()
X, y, groups = make_windows(df)
model = fit_full(X, y)

explainer = shap.TreeExplainer(model)
sv = explainer.shap_values(X)          # (n, n_features, n_classes)
sv = np.array(sv)
print("shap array shape:", sv.shape)

# ---- global importance: mean |SHAP| averaged over classes ------------
# axis 0 = samples, axis 1 = features, axis 2 = classes
mean_abs = np.abs(sv).mean(axis=0)                 # (features, classes)
overall  = mean_abs.mean(axis=1)                   # (features,)

imp = pd.DataFrame({
    "feature": X.columns,
    "shap_overall": overall,
}).sort_values("shap_overall", ascending=False).reset_index(drop=True)

for k, name in enumerate(LEVELS):
    imp[f"shap_{name.lower()}"] = [mean_abs[list(X.columns).index(f), k]
                                   for f in imp.feature]

# ---- gain-based, for comparison --------------------------------------
gain = pd.Series(model.feature_importances_, index=X.columns)
imp["gain"] = imp.feature.map(gain)
imp["rank_shap"] = range(1, len(imp)+1)
imp["rank_gain"] = imp.gain.rank(ascending=False).astype(int)
imp["rank_shift"] = imp.rank_gain - imp.rank_shap

imp.to_csv("out/shap_importance.csv", index=False)
print()
print(imp[["feature","shap_overall","gain","rank_shap","rank_gain","rank_shift"]]
      .round(4).to_string(index=False))

# ======================================================================
# Figures
# ======================================================================
NAVY   = "#1A3C6E"
CORAL  = "#FF6B5B"
AMBER  = "#854F0B"
GREEN  = "#3B6D11"
CLASS_COLORS = [GREEN, AMBER, CORAL, "#A32D2D"]

plt.rcParams.update({"font.size": 9, "axes.spines.top": False,
                     "axes.spines.right": False})

# ---- Fig 1: global SHAP importance ----------------------------------
fig, ax = plt.subplots(figsize=(7.2, 4.6))
d = imp.sort_values("shap_overall")
ax.barh(d.feature, d.shap_overall, color=NAVY, height=0.7)
ax.set_xlabel("mean |SHAP value|  (average impact on model output)")
ax.set_title("Feature importance by SHAP", loc="left",
             fontweight="bold", color=NAVY)
plt.tight_layout(); plt.savefig("out/fig_shap_global.png", dpi=200); plt.close()

# ---- Fig 2: SHAP vs gain ranking -------------------------------------
fig, ax = plt.subplots(figsize=(7.6, 5.0))
d = imp.sort_values("rank_shap")
yv = np.arange(len(d))
for i, r in enumerate(d.itertuples()):
    ax.plot([r.rank_gain, r.rank_shap], [i, i], color="#BBBBBB", lw=1, zorder=1)
    ax.scatter(r.rank_gain, i, color="#BBBBBB", s=28, zorder=2)
    col = CORAL if abs(r.rank_shift) >= 5 else NAVY
    ax.scatter(r.rank_shap, i, color=col, s=34, zorder=3)
ax.set_yticks(yv); ax.set_yticklabels(d.feature)
ax.invert_yaxis()
ax.set_xlabel("rank  (1 = most important)")
ax.set_title("Gain ranking (grey) versus SHAP ranking (blue)\n"
             "red = shifted by 5 or more places", loc="left",
             fontweight="bold", color=NAVY)
plt.tight_layout(); plt.savefig("out/fig_shap_vs_gain.png", dpi=200); plt.close()

# ---- Fig 3: per-class importance, top 8 ------------------------------
top8 = imp.head(8).feature.tolist()
idx = [list(X.columns).index(f) for f in top8]
fig, ax = plt.subplots(figsize=(8.0, 4.4))
w = 0.2
for k, name in enumerate(LEVELS):
    vals = [mean_abs[i, k] for i in idx]
    ax.bar(np.arange(len(top8)) + k*w - 1.5*w, vals, width=w,
           label=name, color=CLASS_COLORS[k])
ax.set_xticks(np.arange(len(top8))); ax.set_xticklabels(top8, rotation=30, ha="right")
ax.set_ylabel("mean |SHAP value|")
ax.set_title("Which features drive each risk level", loc="left",
             fontweight="bold", color=NAVY)
ax.legend(frameon=False, ncol=4)
plt.tight_layout(); plt.savefig("out/fig_shap_per_class.png", dpi=200); plt.close()

# ---- Fig 4: beeswarm for the CRITICAL class --------------------------
plt.figure()
shap.summary_plot(sv[:, :, 3], X, show=False, max_display=12,
                  plot_size=(7.4, 4.8))
plt.title("SHAP values for the CRITICAL class", loc="left",
          fontweight="bold", color=NAVY)
plt.tight_layout(); plt.savefig("out/fig_shap_critical.png", dpi=200); plt.close()

# ---- per-class table --------------------------------------------------
per_class = pd.DataFrame(mean_abs, index=X.columns,
                         columns=[l.lower() for l in LEVELS])
per_class["overall"] = overall
per_class.sort_values("overall", ascending=False).round(4)\
         .to_csv("out/shap_per_class.csv")

summary = {
  "n_windows": int(len(X)),
  "n_features": int(X.shape[1]),
  "top5_shap": imp.head(5).feature.tolist(),
  "top5_gain": imp.sort_values("gain", ascending=False).head(5).feature.tolist(),
  "largest_rank_shifts": imp.reindex(
      imp.rank_shift.abs().sort_values(ascending=False).index
  ).head(4)[["feature","rank_gain","rank_shap","rank_shift"]].to_dict("records"),
}
json.dump(summary, open("out/shap_summary.json","w"), indent=2)
print()
print(json.dumps(summary, indent=2))
