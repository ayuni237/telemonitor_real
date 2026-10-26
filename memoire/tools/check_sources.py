"""Similarity of the thesis with the texts of its sources.

1. Copied runs: word sequences of >= 8 words found verbatim in a source.
2. Close paraphrase: share of a paragraph's 4-word sequences found in the source it cites.
"""
import re, sys
from collections import defaultdict
from pathlib import Path

src_dir = Path(sys.argv[1])
t = open('memoire_restructure.tex', encoding='utf8').read()
body = t[t.index(r'\chapter{General Introduction}'):t.index(r'\printbibliography')]
body = re.sub(r'(?<!\\)%.*', '', body)
body = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', ' ', body, flags=re.S)

def toks(x):
    x = re.sub(r'\\(label|cref|Cref|ref)\{[^}]*\}', ' ', x)
    x = re.sub(r'\\[a-zA-Z]+\*?', ' ', x)
    x = x.replace('--', ' ').replace('~', ' ').replace('\\,', '')
    return re.findall(r"[a-z]+|[0-9]+(?:\.[0-9]+)?", x.lower())

sources = {}
for f in sorted(src_dir.glob('*.txt')):
    key = f.name.split('.')[0]
    sources.setdefault(key, []).append(toks(f.read_text(encoding='utf8')))
extra = sys.argv[2:]  # optional extra documents, e.g. the student's own earlier review
for path in extra:
    sources[Path(path).stem] = [toks(open(path, encoding='utf8').read())]

N = 8
index = defaultdict(set)
for key, docs in sources.items():
    for w in docs:
        for a in range(len(w) - N + 1):
            index[' '.join(w[a:a + N])].add(key)
grams4 = {key: {' '.join(w[a:a + 4]) for w in docs for a in range(len(w) - 3)} for key, docs in sources.items()}

# paragraphs with their section
marks, c, s, ss = [], 0, 0, 0
for m in re.finditer(r'\\(chapter|section|subsection)\{', body):
    if m.group(1) == 'chapter': c += 1; s = ss = 0
    elif m.group(1) == 'section': s += 1; ss = 0
    else: ss += 1
    marks.append((m.start(), f'{c}.{s}' + (f'.{ss}' if ss else '')))
paras, pos = [], 0
for block in re.split(r'\n\s*\n', body):
    sec = [n for p, n in marks if p <= pos]
    pos += len(block) + 2
    if len(toks(block)) >= 20:
        paras.append((sec[-1] if sec else '?', block))

STOP = set('the of and in to a for with on by at is are was were as an or from that this be which'.split())
runs = []
close = []
for sec, block in paras:
    w = toks(block)
    # 1. verbatim runs
    a = 0
    while a <= len(w) - N:
        g = ' '.join(w[a:a + N])
        if g in index:
            keys = set(index[g]); b = a + N
            while b < len(w) and ' '.join(w[b - N + 1:b + 1]) in index:
                keys &= index[' '.join(w[b - N + 1:b + 1])] or keys
                b += 1
            runs.append((b - a, sec, sorted(keys), ' '.join(w[a:b])))
            a = b
        else:
            a += 1
    # 2. close paraphrase against the cited works of the paragraph
    cited = set(k.strip() for g in re.findall(r'\\(?:parencite|textcite|Textcite)\{([^}]*)\}', block) for k in g.split(','))
    g4 = [' '.join(w[i:i + 4]) for i in range(len(w) - 3)]
    g4 = [g for g in g4 if sum(x not in STOP and not x.replace('.', '').isdigit() for x in g.split()) >= 2]
    for k in cited & set(grams4):
        if len(g4) >= 15:
            share = sum(g in grams4[k] for g in g4) / len(g4)
            close.append((share, sec, k, len(w)))

runs.sort(reverse=True)
print(f'== verbatim runs of >= {N} words found in a source: {len(runs)}')
for L, sec, keys, txt in runs[:40]:
    print(f'{L:3d} words  §{sec:7s} {",".join(keys)[:40]:40s} "{txt[:160]}"')
close.sort(reverse=True)
print(f'\n== close paraphrase: share of 4-word sequences shared with the cited source (top 25 of {len(close)})')
for share, sec, k, n in close[:25]:
    print(f'{100*share:5.1f}%  §{sec:7s} {k:20s} ({n} words)')
