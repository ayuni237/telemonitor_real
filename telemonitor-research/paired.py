import numpy as np, warnings
from sklearn.model_selection import GroupKFold
from sklearn.metrics import roc_auc_score
from sklearn.utils import check_random_state
from xgboost import XGBClassifier
from scipy.stats import wilcoxon
from train import load
warnings.filterwarnings('ignore')
X,y,g,meta=load(1); yb=(y>=2).astype(int); obs=meta.glucose_observed.to_numpy()
Xs,ys,gs=X[obs],yb[obs],g[obs]
A=list(range(16)); B=[0,3,4,7,8,11,12,15]   # full 16 vs mean+last 8

def one(cols,seed,perm):
    gg = np.array([perm[v] for v in gs])     # permuted patient ids -> different fold partitions
    pr=np.zeros(len(ys))
    for tr,te in GroupKFold(n_splits=5).split(Xs,ys,gg):
        c=np.bincount(ys[tr],minlength=2); spw=c[0]/max(c[1],1)
        m=XGBClassifier(n_estimators=150,max_depth=2,learning_rate=0.05,min_child_weight=5,
          reg_lambda=5.0,subsample=0.9,colsample_bytree=0.9,objective='binary:logistic',
          scale_pos_weight=spw,tree_method='hist',random_state=seed,n_jobs=4)
        m.fit(Xs[tr][:,cols],ys[tr]); pr[te]=m.predict_proba(Xs[te][:,cols])[:,1]
    return roc_auc_score(ys,pr)

pats=sorted(set(gs)); rs=check_random_state(7); a=[];b=[]
for r in range(30):
    sh=rs.permutation(len(pats)); perm={p:int(sh[i]) for i,p in enumerate(pats)}
    a.append(one(A,r,perm)); b.append(one(B,r,perm))
a,b=np.array(a),np.array(b)
st,p = wilcoxon(b,a)
print("PAIRED COMPARISON — 30 independent patient-level fold partitions, glucose-observed subset")
print(f"  full 16 features : ROC-AUC {a.mean():.3f} (SD {a.std():.3f})")
print(f"  mean+last 8      : ROC-AUC {b.mean():.3f} (SD {b.std():.3f})")
print(f"  difference       : {b.mean()-a.mean():+.3f}   Wilcoxon signed-rank p = {p:.4f}")
print(f"  8-feature set wins in {(b>a).sum()}/30 partitions")
