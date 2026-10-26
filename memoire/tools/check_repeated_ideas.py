"""Where each recurring idea of the thesis appears (section numbers)."""
import re
t = open('memoire_restructure.tex', encoding='utf8').read()
body = t[t.index(r'\chapter{General Introduction}'):t.index(r'\printbibliography')]
body = re.sub(r'(?<!\\)%.*', '', body)
body = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', ' ', body, flags=re.S)
marks = []
c = s = ss = 0
for m in re.finditer(r'\\(chapter|section|subsection)\{', body):
    if m.group(1) == 'chapter': c += 1; s = ss = 0
    elif m.group(1) == 'section': s += 1; ss = 0
    else: ss += 1
    marks.append((m.start(), f'{c}.{s}' + (f'.{ss}' if ss else '')))
def where(pos):
    h = [n for p, n in marks if p <= pos]
    return h[-1] if h else '?'
facts = [
    ('Efendi: label leakage (deterministic label)', r'deterministic function|recover(s)? a rule|recovery of a rule'),
    ('Efendi: six participants / ten minutes', r'[Ss]ix (participants|volunteers)'),
    ('Efendi: stores only current values', r'one current value per parameter'),
    ('Efendi: XGBoost best vs Mendoza worst', r'XGBoost.{0,80}(best|chance|worst)'),
    ('Mendoza: reporting errors (positive class / sensitivity)', r'positive class is not the same|attributes to random forest|different positive class'),
    ('Mendoza: RF misses half (sensitivity 0.51)', r'misses half|0\.51'),
    ('Mihevc: patients unable to use equipment', r'could not use the equipment'),
    ('Mihevc: fixed thresholds / level not trend', r'level of a reading rather than'),
    ('Mihevc: effect via treatment adjustment, not behaviour change', r'not (from )?behaviour change|treatment adjustment, not'),
    ('Bediang: 10.3 days specialist delay', r'10\.3'),
    ('Bediang: diagnosis changed 46.2%', r'46\.2'),
    ('WHO: cuffless devices not accepted', r'[Cc]uffless'),
    ('WHO: Recommendation 7 follow-up frequency', r'Recommendation~?\s?7'),
    ('Loss to follow-up affects half', r'half of patients or more'),
    ('Lifestyle lowers SBP by 1.3 mmHg', r'1\.3~mmHg'),
    ('Professionals see telemedicine as extra work', r'additional (task|work)|extra work'),
    ('Specialists scarce', r'scarce|scarcity'),
    ('550 million without electricity/internet', r'550 million'),
    ('Rule floor: model raises, never lowers', r'never lower'),
    ('Clinician verdict = label', r'verdict'),
    ('Data residency / region / transfer abroad', r'residency|region outside|transfer abroad'),
    ('Law 2024/017', r'2024/017'),
    ('GDPR', r'GDPR'),
    ('pi = 0.02 planning prevalence', r'\\pi = 0\.02|0\.02'),
    ('Variance / sqrt(14) = 3.7', r'3\.7'),
    ('135/85 home threshold', r'135/85'),
    ('Missing glucose informative / ordered for some', r'ordered for some patients|ordered according to the clinical'),
    ('Interpolation invents values', r'invent'),
    ('MAD personalised threshold', r'personalised threshold'),
    ('Alert volume / precision at low prevalence', r'99\.5|alert volume'),
    ('Offline: lost readings become delayed', r'delayed reading'),
    ('Device validation register / validated devices only', r'validated device|validation register'),
    ('Glucose unit conversion 18.0156 / mg/dL vs mmol/L', r'18\.0|mg/dL'),
]
for name, pat in facts:
    hits = [where(m.start()) for m in re.finditer(pat, body)]
    secs = sorted(set(hits), key=lambda x: [int(v) for v in x.split('.')])
    if len(secs) >= 2:
        print(f'{len(hits):3d}x {len(secs):2d} sections | {name:55s} | {", ".join(secs)}')
