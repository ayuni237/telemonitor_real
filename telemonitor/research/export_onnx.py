import numpy as np, onnxruntime as ort, warnings
from xgboost import XGBClassifier
from onnxmltools.convert import convert_xgboost
from onnxmltools.convert.common.data_types import FloatTensorType
from train import load
warnings.filterwarnings('ignore')

X,y,g,meta = load(1)
m = XGBClassifier(); m.load_model('telemonitor_risk_model.json')

onx = convert_xgboost(m, initial_types=[('input', FloatTensorType([None, 16]))],
                      target_opset=15)
with open('telemonitor_risk_model.onnx','wb') as f: f.write(onx.SerializeToString())
import os; print(f"onnx written: {os.path.getsize('telemonitor_risk_model.onnx')/1024:.1f} KB")

sess = ort.InferenceSession('telemonitor_risk_model.onnx', providers=['CPUExecutionProvider'])
inp = sess.get_inputs()[0].name
print("inputs :", [(i.name,i.shape,i.type) for i in sess.get_inputs()])
print("outputs:", [(o.name,o.shape) for o in sess.get_outputs()])

Xf = X.astype(np.float32)
ref = m.predict_proba(X)
out = sess.run(None, {inp: Xf})
prob = out[1]
if isinstance(prob, list):            # ZipMap output
    prob = np.array([[r[k] for k in sorted(r)] for r in prob])
d = np.abs(prob - ref)
print(f"\nPARITY on all {len(X)} real windows (incl. {int(np.isnan(X).any(1).sum())} with a NaN glucose channel)")
print(f"  max |ONNX - XGBoost| probability difference : {d.max():.3e}")
print(f"  mean difference                            : {d.mean():.3e}")
print(f"  argmax agreement                           : {(prob.argmax(1)==ref.argmax(1)).mean()*100:.2f}%")

nanmask = np.isnan(X).any(1)
if nanmask.sum():
    print(f"  max difference on NaN-containing rows only : {d[nanmask].max():.3e}")

# risk score R = P(high) + P(critical)
R_ref = ref[:,2]+ref[:,3]; R_onx = prob[:,2]+prob[:,3]
print(f"  max |ΔR| for the deployed risk score        : {np.abs(R_ref-R_onx).max():.3e}")
np.save('risk_scores.npy', R_ref)
print(f"\n  R distribution: min {R_ref.min():.3f}  median {np.median(R_ref):.3f}  max {R_ref.max():.3f}")
