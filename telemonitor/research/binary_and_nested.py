import numpy as np, warnings, itertools
from sklearn.model_selection import GroupKFold
from sklearn.metrics import (roc_auc_score, average_precision_score, accuracy_score,
                             balanced_accuracy_score, f1_score, confusion_matrix,
                             precision_recall_fscore_support)
from xgboost import XGBClassifier
from train import load, weights, model, cv, NAMES
import features as F
warnings.filterwarnings('ignore')
X,y,g,meta = load(1)

# ---------- A. NESTED CV for the 4-class model (honest, no selection bias) ----------
GRID = list(itertools.product([60,150],[2,3,4],[0.05],[1,5],[1.0,5.0]))
outer = GroupKFold(n_splits=5)
oof = np.full(len(y),-1,int)
picked=[]
for tr,te in outer.split(X,y,g):
    Xi,yi,gi = X[tr],y[tr],g[tr]
    best=(-1,None)
    for ne,dp,lr,mcw,lam in GRID:
        inner = GroupKFold(n_splits=4); p=np.full(len(yi),-1,int)
        for a,b in inner.split(Xi,yi,gi):
            w=weights(yi[a])
            m=model(n_estimators=ne,max_depth=dp,learning_rate=lr,
                    min_child_weight=mcw,reg_lambda=lam).fit(Xi[a],yi[a],sample_weight=w[yi[a]])
            p[b]=m.predict(Xi[b])
        s=f1_score(yi,p,average='macro')
        if s>best[0]: best=(s,(ne,dp,lr,mcw,lam))
    ne,dp,lr,mcw,lam = best[1]; picked.append(best[1])
    w=weights(yi)
    m=model(n_estimators=ne,max_depth=dp,learning_rate=lr,min_child_weight=mcw,
            reg_lambda=lam).fit(Xi,yi,sample_weight=w[yi])
    oof[te]=m.predict(X[te])
print("NESTED CV (hyperparameters chosen inside each training fold — no selection leak)")
print(f"  accuracy {accuracy_score(y,oof):.3f} | balanced {balanced_accuracy_score(y,oof):.3f} "
      f"| macro-F1 {f1_score(y,oof,average='macro'):.3f}")
print(f"  configs chosen per outer fold: {picked}")
pers = np.array([F.level(x[3],x[7],x[11]) for x in X])
print(f"  persistence baseline            : accuracy {accuracy_score(y,pers):.3f} | "
      f"balanced {balanced_accuracy_score(y,pers):.3f} | macro-F1 {f1_score(y,pers,average='macro'):.3f}")

# ---------- B. THE OPERATIONAL TASK: will the next reading need an alert? ----------
print("\n" + "="*70)
print("BINARY ALERT TASK  —  y = 1 if next reading is high OR critical")
print("="*70)
yb = (y>=2).astype(int)
print(f"  prevalence {yb.mean():.3f} ({yb.sum()}/{len(yb)})")
probs = np.zeros(len(yb))
for tr,te in GroupKFold(n_splits=5).split(X,yb,g):
    cnt=np.bincount(yb[tr],minlength=2); spw=cnt[0]/max(cnt[1],1)
    m=XGBClassifier(n_estimators=150,max_depth=2,learning_rate=0.05,min_child_weight=5,
                    reg_lambda=5.0,subsample=0.9,colsample_bytree=0.9,
                    objective='binary:logistic',scale_pos_weight=spw,
                    tree_method='hist',random_state=42,n_jobs=4).fit(X[tr],yb[tr])
    probs[te]=m.predict_proba(X[te])[:,1]
np.save('probs_bin.npy',probs); np.save('yb.npy',yb)
auc=roc_auc_score(yb,probs); ap=average_precision_score(yb,probs)
print(f"  ROC-AUC {auc:.3f}   PR-AUC {ap:.3f}  (chance PR-AUC = {yb.mean():.3f})")
persb=(pers>=2).astype(int)
print(f"  persistence baseline: ROC-AUC {roc_auc_score(yb,persb):.3f}  PR-AUC {average_precision_score(yb,persb):.3f}")
print(f"\n  {'threshold':>10}{'sens':>8}{'spec':>8}{'PPV':>8}{'alerts/100':>12}")
for t in [0.3,0.4,0.5,0.6,0.7]:
    pr=(probs>=t).astype(int)
    tn,fp,fn,tp = confusion_matrix(yb,pr,labels=[0,1]).ravel()
    sens=tp/max(tp+fn,1); spec=tn/max(tn+fp,1); ppv=tp/max(tp+fp,1)
    print(f"  {t:10.2f}{sens:8.3f}{spec:8.3f}{ppv:8.3f}{100*pr.mean():12.1f}")
prb=(pers>=2).astype(int)
tn,fp,fn,tp=confusion_matrix(yb,prb,labels=[0,1]).ravel()
print(f"  {'persist':>10}{tp/max(tp+fn,1):8.3f}{tn/max(tn+fp,1):8.3f}{tp/max(tp+fp,1):8.3f}{100*prb.mean():12.1f}")
