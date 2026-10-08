import numpy as np, itertools, warnings
from sklearn.metrics import f1_score, accuracy_score, balanced_accuracy_score
from train import load, cv, weights, model
warnings.filterwarnings('ignore')
X,y,g,meta = load(1)
print(f"n={len(y)} windows, p={X.shape[1]} features, {len(set(g))} patients -> "
      f"{len(y)/X.shape[1]:.1f} samples per feature\n")
print(f"{'n_est':>6}{'depth':>6}{'lr':>6}{'minchild':>9}{'lambda':>8}   {'acc':>6}{'balacc':>8}{'macroF1':>9}")
best=None
for n_est,depth,lr,mcw,lam in itertools.product([60,150,300],[2,3,4],[0.05,0.1],[1,5],[1.0,5.0]):
    o,_ = cv(X,y,g,n_estimators=n_est,max_depth=depth,learning_rate=lr,
             min_child_weight=mcw,reg_lambda=lam)
    a,b,f = accuracy_score(y,o), balanced_accuracy_score(y,o), f1_score(y,o,average='macro')
    if best is None or f>best[0]: best=(f,n_est,depth,lr,mcw,lam,a,b)
    if f>0.40: print(f"{n_est:6d}{depth:6d}{lr:6.2f}{mcw:9d}{lam:8.1f}   {a:6.3f}{b:8.3f}{f:9.3f}")
print(f"\nbest macro-F1 {best[0]:.3f} at n_est={best[1]} depth={best[2]} lr={best[3]} "
      f"min_child_weight={best[4]} lambda={best[5]}  (acc {best[6]:.3f}, bal {best[7]:.3f})")
