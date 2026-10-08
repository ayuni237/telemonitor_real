import numpy as np, pandas as pd, joblib
from xgboost import XGBClassifier
from gen import generate, LEVELS
from train import make_windows, P_TRAJ

CRIT_BOOST = 3.0
df = generate(n_patients=60, days=45, seed=42, p_traj=P_TRAJ)
X,y,groups = make_windows(df)
freq=np.bincount(y,minlength=4); w = freq.sum()/(4*np.maximum(freq,1))
w[3]*=CRIT_BOOST; w[2]*=CRIT_BOOST*0.5
sw = w[y]

m = XGBClassifier(n_estimators=300,max_depth=4,learning_rate=0.1,
                  objective="multi:softprob",num_class=4,
                  eval_metric="mlogloss",random_state=42,n_jobs=-1)
m.fit(X,y,sample_weight=sw)
joblib.dump(m,"xgb_final.joblib")
X.to_csv("X_ref.csv",index=False); np.save("y_ref.npy",y)
open("feature_order.txt","w").write("\n".join(X.columns))
imp=pd.Series(m.feature_importances_,index=X.columns).sort_values(ascending=False)
print("top 6:",list(imp.index[:6]))
print("saved")
