"""Redundancy inside the thesis: similar paragraphs, restated sentences, repeated phrases."""
import re
from collections import defaultdict
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

t = open('memoire_restructure.tex', encoding='utf8').read()
body = t[t.index(r'\chapter{General Introduction}'):t.index(r'\printbibliography')]
body = re.sub(r'(?<!\\)%.*', '', body)
body = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', '\n\n', body, flags=re.S)

# walk the body, keeping the current section number for every paragraph
chap = sec = sub = 0
paras = []
for block in re.split(r'\n\s*\n', body):
    for m in re.finditer(r'\\(chapter|section|subsection)\{', block):
        if m.group(1) == 'chapter': chap += 1; sec = 0; sub = 0
        elif m.group(1) == 'section': sec += 1; sub = 0
        else: sub += 1
    paras.append((f'{chap}.{sec}.{sub}', block))

def clean(x):
    x = re.sub(r'\\(label|cref|Cref|ref)\{[^}]*\}', ' ', x)
    x = re.sub(r'\\(parencite|textcite|Textcite)\{([^}]*)\}', r' [\2] ', x)
    x = re.sub(r'\\begin\{(tabularx|tabular)\}(\{[^}]*\})*', ' ', x)
    x = re.sub(r'\\[a-zA-Z]+\*?', ' ', x)
    x = re.sub(r'[{}$\\&~^_]', ' ', x)
    return re.sub(r'\s+', ' ', x).strip()

P = [(s, clean(b)) for s, b in paras if len(clean(b).split()) >= 25]
vec = TfidfVectorizer(ngram_range=(1, 2), stop_words='english', sublinear_tf=True)
X = vec.fit_transform([p[1] for p in P])
S = cosine_similarity(X)
pairs = sorted(((S[i, j], i, j) for i in range(len(P)) for j in range(i + 1, len(P))
                if P[i][0].rsplit('.', 1)[0] != P[j][0].rsplit('.', 1)[0] and S[i, j] > 0.22), reverse=True)
print(f'== {len(P)} paragraphs; {len(pairs)} pairs in different sections with similarity > 0.22')
for sc, i, j in pairs[:30]:
    print(f'\n{sc:.2f}  §{P[i][0]}  vs  §{P[j][0]}')
    print('   A:', P[i][1][:230])
    print('   B:', P[j][1][:230])

# sentence level
sents = []
for s, x in P:
    x2 = re.sub(r'\b(e\.g|i\.e|et al|vs|approx|Fig|Eq)\.', r'\1', x)
    for z in re.split(r'(?<=[a-z0-9\)\]%])\. (?=[A-Z])', x2):
        if len(z.split()) >= 10:
            sents.append((s, z))
Y = TfidfVectorizer(ngram_range=(1, 2), stop_words='english', sublinear_tf=True).fit_transform([z for _, z in sents])
T = cosine_similarity(Y)
sp = sorted(((T[i, j], i, j) for i in range(len(sents)) for j in range(i + 1, len(sents))
             if sents[i][0].rsplit('.', 1)[0] != sents[j][0].rsplit('.', 1)[0] and T[i, j] > 0.45), reverse=True)
print(f'\n\n== {len(sents)} sentences; {len(sp)} pairs of restated sentences (similarity > 0.45) in different sections')
for sc, i, j in sp[:45]:
    print(f'\n{sc:.2f}  §{sents[i][0]} vs §{sents[j][0]}')
    print('   A:', sents[i][1][:200])
    print('   B:', sents[j][1][:200])

# repeated 7-word phrases across paragraphs of different sections
occ = defaultdict(set)
for k, (s, x) in enumerate(P):
    w = re.findall(r"[a-z0-9]+", x.lower())
    for a in range(len(w) - 6):
        occ[' '.join(w[a:a + 7])].add(k)
rep = [(g, ks) for g, ks in occ.items() if len({P[k][0].rsplit('.', 1)[0] for k in ks}) > 1]
print(f'\n\n== {len(rep)} seven-word phrases repeated in different sections (first 40 groups)')
seen = set()
for g, ks in sorted(rep, key=lambda r: (-len(r[1]), r[0]))[:200]:
    key = tuple(sorted(ks))
    if key in seen: continue
    seen.add(key)
    print(len(ks), '|', g, '|', sorted({P[k][0] for k in ks}))
    if len(seen) >= 40: break
