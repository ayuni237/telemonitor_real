import numpy as np, pandas as pd, features as F
from sklearn.model_selection import GroupKFold
from sklearn.metrics import (accuracy_score, f1_score, precision_recall_fscore_support,
                             confusion_matrix, balanced_accuracy_score, cohen_kappa_score)
from xgboost import XGBClassifier

NAMES = ['stable','moderate','high','critical']
SEED  = 42

def load(horizon=1):
    d = pd.read_csv('cohortB_complete.csv', parse_dates=['date'])
    d['seq'] = d.groupby('patient').cumcount()
    return F.make_windows(d, horizon=horizon)

def weights(y):
    """Inverse-frequency, then an extra factor on the two classes whose
    misses are clinically costly."""
    cnt = np.bincount(y, minlength=4).astype(float)
    w = cnt.sum() / (4.0 * np.maximum(cnt, 1))
    w[2] *= 1.5; w[3] *= 3.0
    return w

def model(seed=SEED, **kw):
    p = dict(n_estimators=300, max_depth=4, learning_rate=0.1,
             subsample=0.9, colsample_bytree=0.9, reg_lambda=1.0,
             objective='multi:softprob', num_class=4, tree_method='hist',
             random_state=seed, n_jobs=4)
    p.update(kw)
    return XGBClassifier(**p)

def cv(X, y, groups, n_splits=5, **kw):
    oof = np.full(len(y), -1, int); oofp = np.zeros((len(y), 4))
    for tr, te in GroupKFold(n_splits=n_splits).split(X, y, groups):
        w = weights(y[tr])
        m = model(**kw).fit(X[tr], y[tr], sample_weight=w[y[tr]])
        oof[te] = m.predict(X[te]); oofp[te] = m.predict_proba(X[te])
    return oof, oofp

def report(y, pred, title):
    print(f"\n{'='*66}\n{title}\n{'='*66}")
    print(f"accuracy {accuracy_score(y,pred):.3f} | balanced acc {balanced_accuracy_score(y,pred):.3f} "
          f"| macro-F1 {f1_score(y,pred,average='macro'):.3f} | kappa {cohen_kappa_score(y,pred,weights='quadratic'):.3f}")
    p,r,f,s = precision_recall_fscore_support(y,pred,labels=[0,1,2,3],zero_division=0)
    print(f"\n{'class':10s} {'prec':>6} {'rec':>6} {'F1':>6} {'n':>5}")
    for i,n in enumerate(NAMES):
        print(f"{n:10s} {p[i]:6.3f} {r[i]:6.3f} {f[i]:6.3f} {s[i]:5d}")
    cm = confusion_matrix(y,pred,labels=[0,1,2,3])
    print(f"\nconfusion (rows = true, cols = predicted)\n{'':10s}" + ''.join(f'{n:>10}' for n in NAMES))
    for i,n in enumerate(NAMES):
        print(f"{n:10s}" + ''.join(f'{v:10d}' for v in cm[i]))
    crit_low = cm[3,0] + cm[3,1]
    print(f"\ncritical graded as stable/moderate : {crit_low} of {cm[3].sum()} "
          f"({100*crit_low/max(cm[3].sum(),1):.1f}%)")
    return cm

if __name__ == '__main__':
    # ---- 1. leakage demonstration -------------------------------------
    X0,y0,g0,_ = load(horizon=0)
    o0,_ = cv(X0,y0,g0)
    print(f"NOWCAST (label = last reading in the window): accuracy {accuracy_score(y0,o0):.3f}  <-- label is a "
          f"deterministic function of three features; this is leakage, not skill")

    # ---- 2. the real task ---------------------------------------------
    X,y,g,meta = load(horizon=1)
    oof,oofp = cv(X,y,g)
    np.save('oof.npy',oof); np.save('oofp.npy',oofp); np.save('X.npy',X); np.save('y.npy',y); np.save('g.npy',g)
    report(y,oof,"FORECAST — XGBoost, patient-disjoint GroupKFold (5 folds), n=%d windows, %d patients"%(len(y),len(set(g))))

    # ---- 3. baselines --------------------------------------------------
    maj = np.full_like(y, np.bincount(y).argmax())
    print(f"\nbaseline  majority class            : accuracy {accuracy_score(y,maj):.3f}  macro-F1 {f1_score(y,maj,average='macro'):.3f}")
    # persistence: the level of the LAST observed reading in the window
    pers = np.array([F.level(x[3], x[7], x[11]) for x in X])
    print(f"baseline  persistence (carry last)  : accuracy {accuracy_score(y,pers):.3f}  macro-F1 {f1_score(y,pers,average='macro'):.3f} "
          f"| balanced acc {balanced_accuracy_score(y,pers):.3f}")
    cmp_ = confusion_matrix(y,pers,labels=[0,1,2,3])
    print(f"           persistence misses {cmp_[3,0]+cmp_[3,1]} of {cmp_[3].sum()} critical as stable/moderate")
