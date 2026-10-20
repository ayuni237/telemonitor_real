"""Exploratory PCA analysis of the earlier 16-descriptor pipeline (notebook protocol).

Reproduces the analysis discussed on 2026-10-19 (answer to "PCA for model validation"):
  * the 16 descriptors carry about 7 independent dimensions (7 components for 80% of variance;
    participation ratio 7.25); PC1 = blood-pressure level, PC2 = glucose, PC3 = pulse;
  * on the stratum with glucose observed (106 windows, 18 patients), 30 patient-level re-partitions:
    XGBoost 16 features ROC-AUC 0.675; logistic regression on 2 components 0.683; XGBoost on PCA ~0.60.
It deliberately uses the EARLIER pipeline (root-level features.py, notebook labels and XGBoost
configuration) to reproduce the notebook's numbers. The Wilcoxon p-values printed here treat the
30 re-partitions as independent, which overstates significance (thesis §Training protocol): the
benchmark of the thesis uses the corrected resampled t test instead.
"""
import os
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))          # root-level features.py of the earlier pipeline
os.chdir(ROOT)
import numpy as np, pandas as pd, warnings, features as F
from sklearn.model_selection import GroupKFold
from sklearn.metrics import roc_auc_score, average_precision_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.linear_model import LogisticRegression
from sklearn.utils import check_random_state
from xgboost import XGBClassifier
from scipy.stats import wilcoxon
warnings.filterwarnings('ignore')
d = pd.read_csv('cohortB_complete.csv', parse_dates=['date']); d['seq']=d.groupby('patient').cumcount()
X,y,g,meta = F.make_windows(d, horizon=1)
obs = meta.glucose_observed.to_numpy()
Xs, ys, gs = X[obs], (y[obs]>=2).astype(int), g[obs]
print(f'primary stratum n={len(ys)} windows, {len(set(gs))} patients, prev {ys.mean():.3f}')
# 1. redundancy of the 16 features
Z = StandardScaler().fit_transform(Xs); ev = PCA().fit(Z).explained_variance_ratio_
cum = ev.cumsum()
print('explained variance (cum):', ' '.join(f'{c:.2f}' for c in cum[:10]))
print('components for 80/90/95%:', [int(np.searchsorted(cum,t)+1) for t in (.8,.9,.95)])
lam = PCA().fit(Z).explained_variance_; print('participation ratio (effective dim):', round(lam.sum()**2/(lam**2).sum(),2))
pc = PCA(3).fit(Z); names=F.FEATURE_NAMES
for k in range(3):
    top = np.argsort(-np.abs(pc.components_[k]))[:4]
    print(f' PC{k+1} ({ev[k]:.2f}):', ', '.join(f'{names[i]}{pc.components_[k][i]:+.2f}' for i in top))
# 2. benchmark, same protocol as the notebook: 30 patient-level partitions, PCA fitted in-fold
def xgb(seed): return XGBClassifier(n_estimators=150,max_depth=2,learning_rate=0.05,min_child_weight=5,
    reg_lambda=5.0,subsample=0.9,colsample_bytree=0.9,objective='binary:logistic',tree_method='hist',random_state=seed,n_jobs=4)
def models(seed):
    m = {'XGB 16 raw (deployed config)': lambda: xgb(seed),
         'LogReg 16 standardised': lambda: make_pipeline(StandardScaler(), LogisticRegression(C=1.0,class_weight='balanced',max_iter=2000))}
    for k in (2,3,4,6,8):
        m[f'LogReg on PCA k={k}'] = (lambda k=k: make_pipeline(StandardScaler(), PCA(k), LogisticRegression(class_weight='balanced',max_iter=2000)))
    for k in (3,6):
        m[f'XGB on PCA k={k}'] = (lambda k=k: make_pipeline(StandardScaler(), PCA(k), xgb(seed)))
    return m
pats = sorted(set(gs)); rs = check_random_state(7); res = {}
from tqdm import tqdm
for r in tqdm(range(30), desc='re-partitions', unit='partition'):
    sh = rs.permutation(len(pats)); perm={p:int(sh[i]) for i,p in enumerate(pats)}; gg=np.array([perm[v] for v in gs])
    for name, mk in models(r).items():
        pr = np.zeros(len(ys))
        for tr,te in GroupKFold(5).split(Xs,ys,gg):
            c=np.bincount(ys[tr],minlength=2); m=mk()
            if name.startswith('XGB'):
                sw = np.where(ys[tr]==1, c[0]/max(c[1],1), 1.0)
                if hasattr(m,'steps'): m.fit(Xs[tr],ys[tr],**{m.steps[-1][0]+'__sample_weight':sw})
                else: m.fit(Xs[tr],ys[tr],sample_weight=sw)
            else: m.fit(Xs[tr],ys[tr])
            pr[te]=m.predict_proba(Xs[te])[:,1]
        res.setdefault(name,[]).append((roc_auc_score(ys,pr),average_precision_score(ys,pr)))
pers = np.array([F.level(x[3],x[7],x[11])>=2 for x in Xs]).astype(int)
print(f"\n{'model':32s}{'ROC-AUC':>16}{'PR-AUC':>16}  p(vs XGB16, Wilcoxon)")
base = np.array(res['XGB 16 raw (deployed config)'])[:,0]
for k,v in res.items():
    v=np.array(v); p = '' if k.startswith('XGB 16') else f'{wilcoxon(v[:,0],base).pvalue:.4f}'
    print(f'{k:32s}{v[:,0].mean():9.3f} ±{v[:,0].std():.3f}{v[:,1].mean():9.3f} ±{v[:,1].std():.3f}   {p}')
print(f"{'persistence':32s}{roc_auc_score(ys,pers):9.3f}{'':7s}{average_precision_score(ys,pers):9.3f}")
