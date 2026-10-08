import numpy as np, warnings
from sklearn.model_selection import GroupKFold
from sklearn.metrics import roc_auc_score, average_precision_score
from xgboost import XGBClassifier
from train import load
import features as F
warnings.filterwarnings('ignore')
X,y,g,meta=load(1); yb=(y>=2).astype(int); obs=meta.glucose_observed.to_numpy()
print("IS GLUCOSE-MISSINGNESS ACTING AS A SHORTCUT?")
print(f"  alert prevalence | glucose observed : {yb[obs].mean():.3f}  (n={obs.sum()})")
print(f"  alert prevalence | glucose absent   : {yb[~obs].mean():.3f}  (n={(~obs).sum()})")
print(f"  => a single bit 'was glucose measured?' alone gives ROC-AUC "
      f"{roc_auc_score(yb,obs.astype(int)):.3f}\n")

def run(Xs,ys,gs,cols,seeds=(0,1,2,3,4),folds=5):
    a,p=[],[]
    for s in seeds:
        pr=np.zeros(len(ys))
        for tr,te in GroupKFold(n_splits=folds).split(Xs,ys,gs):
            c=np.bincount(ys[tr],minlength=2); spw=c[0]/max(c[1],1)
            m=XGBClassifier(n_estimators=150,max_depth=2,learning_rate=0.05,min_child_weight=5,
              reg_lambda=5.0,subsample=0.9,colsample_bytree=0.9,objective='binary:logistic',
              scale_pos_weight=spw,tree_method='hist',random_state=s,n_jobs=4)
            m.fit(Xs[tr][:,cols],ys[tr]); pr[te]=m.predict_proba(Xs[te][:,cols])[:,1]
        a.append(roc_auc_score(ys,pr)); p.append(average_precision_score(ys,pr))
    return np.mean(a),np.std(a),np.mean(p),np.std(p)

print("PRIMARY ANALYSIS — restricted to windows where glucose WAS measured")
Xs,ys,gs = X[obs],yb[obs],g[obs]
print(f"  n={len(ys)} windows, {len(set(gs))} patients, prevalence {ys.mean():.3f}")
SETS={'full 16':list(range(16)),'mean+last (8)':[0,3,4,7,8,11,12,15],
      'last only (4)':[3,7,11,15],'no trend/std (8)':[0,3,4,7,8,11,12,15],
      'BP+HR only, no glucose (12)':[i for i in range(16) if not(8<=i<12)]}
print(f"\n  {'feature set':30s}{'ROC-AUC':>16}{'PR-AUC':>16}")
for k,c in SETS.items():
    A,sa,P,sp=run(Xs,ys,gs,c); print(f"  {k:30s}{A:10.3f} ±{sa:.3f}{P:10.3f} ±{sp:.3f}")
persv=(np.array([F.level(x[3],x[7],x[11]) for x in Xs])>=2).astype(int)
print(f"  {'persistence baseline':30s}{roc_auc_score(ys,persv):10.3f}       {average_precision_score(ys,persv):10.3f}")
