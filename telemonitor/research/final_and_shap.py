import numpy as np, pandas as pd, warnings, json, shap
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from xgboost import XGBClassifier
from train import load, weights, NAMES
import features as F
warnings.filterwarnings('ignore')

X,y,g,meta = load(1)
w = weights(y)
# final deployed model: 4-class, all 146 windows, hyperparameters from the nested-CV consensus
final = XGBClassifier(n_estimators=150, max_depth=2, learning_rate=0.05,
                      min_child_weight=5, reg_lambda=5.0, subsample=0.9, colsample_bytree=0.9,
                      objective='multi:softprob', num_class=4, tree_method='hist',
                      random_state=42, n_jobs=4).fit(X, y, sample_weight=w[y])
final.save_model('telemonitor_risk_model.json')
final.get_booster().save_model('telemonitor_risk_model.ubj')

ex = shap.TreeExplainer(final)
sv = ex.shap_values(X)                      # (n, 16, 4)
sv = np.asarray(sv)
print("shap array:", sv.shape)
glob = np.abs(sv).mean(axis=(0, 2))
gain = final.get_booster().get_score(importance_type='gain')
gain = np.array([gain.get(f'f{i}', 0.0) for i in range(16)])
gain = gain / gain.sum() if gain.sum() else gain
tab = pd.DataFrame({'feature': F.FEATURE_NAMES,
                    'shap_mean_abs': glob,
                    'shap_rank': (-glob).argsort().argsort() + 1,
                    'gain': gain,
                    'gain_rank': (-gain).argsort().argsort() + 1})
tab['rank_shift'] = tab.gain_rank - tab.shap_rank
tab = tab.sort_values('shap_mean_abs', ascending=False)
print(tab.to_string(index=False, float_format=lambda v: f'{v:.4f}'))
tab.to_csv('shap_vs_gain.csv', index=False)

# per-class attribution
per = np.abs(sv).mean(axis=0)               # (16, 4)
pd.DataFrame(per, index=F.FEATURE_NAMES, columns=NAMES).to_csv('shap_per_class.csv')
print("\nTop-3 drivers per predicted class")
for k, n in enumerate(NAMES):
    top = np.argsort(-per[:, k])[:3]
    print(f"  {n:9s}: " + ', '.join(f'{F.FEATURE_NAMES[i]} ({per[i,k]:.3f})' for i in top))

# correlation structure, for the gain-bias argument
C = pd.DataFrame(X, columns=F.FEATURE_NAMES).corr()
print(f"\ncorr(sbp_mean, dbp_mean) = {C.loc['sbp_mean','dbp_mean']:.3f}")
print(f"corr(sbp_mean, sbp_last) = {C.loc['sbp_mean','sbp_last']:.3f}")

# ---- figures ----
o = np.argsort(glob)
plt.figure(figsize=(7, 5.5))
plt.barh([F.FEATURE_NAMES[i] for i in o], glob[o], color='#2B6CB0')
plt.xlabel('mean |SHAP value|'); plt.title('Global feature attribution (real cohort, n=146 windows)')
plt.tight_layout(); plt.savefig('fig_shap_global.png', dpi=160); plt.close()

idx = np.argsort(-glob)[:10]
xx = np.arange(len(idx)); wd = 0.38
plt.figure(figsize=(8.5, 4.6))
plt.bar(xx - wd/2, glob[idx]/glob.sum(), wd, label='SHAP (normalised)', color='#2B6CB0')
plt.bar(xx + wd/2, gain[idx], wd, label='Gain (normalised)', color='#C05621')
plt.xticks(xx, [F.FEATURE_NAMES[i] for i in idx], rotation=45, ha='right')
plt.ylabel('share of total importance'); plt.legend()
plt.title('SHAP vs gain-based importance'); plt.tight_layout()
plt.savefig('fig_shap_vs_gain.png', dpi=160); plt.close()

plt.figure(figsize=(8.5, 5))
bot = np.zeros(16); o2 = np.argsort(-glob)
for k, n in enumerate(NAMES):
    plt.bar(range(16), per[o2, k], bottom=bot, label=n)
    bot += per[o2, k]
plt.xticks(range(16), [F.FEATURE_NAMES[i] for i in o2], rotation=45, ha='right')
plt.ylabel('mean |SHAP|'); plt.legend(); plt.title('Per-class attribution')
plt.tight_layout(); plt.savefig('fig_shap_per_class.png', dpi=160); plt.close()
print("\nfigures written")
