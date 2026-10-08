import numpy as np, warnings
from sklearn.model_selection import GroupKFold
from sklearn.metrics import roc_auc_score, average_precision_score, f1_score, accuracy_score
from xgboost import XGBClassifier
from train import load
import features as F
warnings.filterwarnings('ignore')
X,y,g,meta = load(1); yb=(y>=2).astype(int)
NAMES=F.FEATURE_NAMES
SETS = {
 'full 16 (mean,std,trend,last)': list(range(16)),
 'last only (4)'                : [3,7,11,15],
 'mean+last (8)'                : [0,3,4,7,8,11,12,15],
 'no last (12)'                 : [i for i in range(16) if i%4!=3],
 'no glucose channel (12)'      : [i for i in range(16) if not (8<=i<12)],
}
def run(cols, seeds=(0,1,2,3,4)):
    aucs=[];aps=[]
    for s in seeds:
        p=np.zeros(len(yb))
        for tr,te in GroupKFold(n_splits=5).split(X,yb,g):
            c=np.bincount(yb[tr],minlength=2); spw=c[0]/max(c[1],1)
            m=XGBClassifier(n_estimators=150,max_depth=2,learning_rate=0.05,min_child_weight=5,
                reg_lambda=5.0,subsample=0.9,colsample_bytree=0.9,objective='binary:logistic',
                scale_pos_weight=spw,tree_method='hist',random_state=s,n_jobs=4)
            m.fit(X[tr][:,cols],yb[tr]); p[te]=m.predict_proba(X[te][:,cols])[:,1]
        aucs.append(roc_auc_score(yb,p)); aps.append(average_precision_score(yb,p))
    return np.mean(aucs),np.std(aucs),np.mean(aps),np.std(aps)
print("FEATURE ABLATION — binary alert task, 5 seeds x 5 patient-disjoint folds\n")
print(f"{'feature set':32s}{'ROC-AUC':>16}{'PR-AUC':>16}")
for k,c in SETS.items():
    a,sa,p,sp = run(c)
    print(f"{k:32s}{a:10.3f} ±{sa:.3f}{p:10.3f} ±{sp:.3f}")
print(f"\n{'persistence (carry last level)':32s}{roc_auc_score(yb,(np.array([F.level(x[3],x[7],x[11]) for x in X])>=2).astype(int)):10.3f}        "
      f"{average_precision_score(yb,(np.array([F.level(x[3],x[7],x[11]) for x in X])>=2).astype(int)):10.3f}")

# subgroup: windows where glucose was observed vs not
print("\nSUBGROUP — does the model still work when glucose was never measured?")
p=np.zeros(len(yb))
for tr,te in GroupKFold(n_splits=5).split(X,yb,g):
    c=np.bincount(yb[tr],minlength=2); spw=c[0]/max(c[1],1)
    m=XGBClassifier(n_estimators=150,max_depth=2,learning_rate=0.05,min_child_weight=5,reg_lambda=5.0,
        subsample=0.9,colsample_bytree=0.9,objective='binary:logistic',scale_pos_weight=spw,
        tree_method='hist',random_state=42,n_jobs=4).fit(X[tr],yb[tr]); p[te]=m.predict_proba(X[te])[:,1]
obs = meta.glucose_observed.to_numpy()
for lab,mask in [('glucose observed',obs),('glucose absent (NaN branch)',~obs)]:
    if mask.sum()>5 and len(set(yb[mask]))>1:
        print(f"  {lab:30s} n={mask.sum():3d}  prevalence {yb[mask].mean():.2f}  ROC-AUC {roc_auc_score(yb[mask],p[mask]):.3f}")
