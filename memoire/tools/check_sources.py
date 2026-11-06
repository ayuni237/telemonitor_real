"""Similarity of the thesis with the texts of its sources (a pre-check, not the school's software).

Whole document from \\begin{document}: abstract, front lists, chapters and appendices; the
bibliography is left out; long tables are read row by row.
1. Copied runs: word sequences of >= 8 words found verbatim in a source.
2. Share of the thesis words that lie inside such runs, per source.
3. Close paraphrase: share of a paragraph's 4-word sequences found in the source it cites.

Usage, from memoire/: python tools/check_sources.py tools/sources [own_earlier_document.txt ...]
Extra documents are the author's own earlier texts (e.g. the 19-reference review as text):
matches with them are reuse of one's own work, shown as OWN:<name>.
"""
import re, sys
from collections import defaultdict
from pathlib import Path

src_dir = Path(sys.argv[1])
tex = open('memoire_restructure.tex', encoding='utf8').read()
body = tex[tex.index(r'\begin{document}'):tex.index(r'\end{document}')]
body = re.sub(r'(?<!\\)%.*', '', body)
body = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', ' ', body, flags=re.S)
start_app = body.find(r'\printbibliography')  # the appendices follow the bibliography
start_app = start_app if start_app >= 0 else len(body)
body = re.sub(r'\\printbibliography(\[[^\]]*\])?', lambda m: ' ' * len(m.group(0)), body)

CITE = re.compile(r'\\(?:parencite|textcite|Textcite|cite|citeauthor)\*?(?:\[[^\]]*\])*\{([^}]*)\}')

def toks(x):
    x = CITE.sub(' ', x)
    x = re.sub(r'\\(label|cref|Cref|ref|eqref|pageref|includegraphics|input|url|href)(\[[^\]]*\])?\{[^}]*\}', ' ', x)
    x = re.sub(r'\\[a-zA-Z]+\*?', ' ', x)
    x = x.replace('--', ' ').replace('~', ' ').replace('\\,', '')
    return re.findall(r"[a-z]+|[0-9]+(?:\.[0-9]+)?", x.lower())

def toks_src(x):
    return re.findall(r"[a-z]+|[0-9]+(?:\.[0-9]+)?", x.lower())

sources = {}
for f in sorted(src_dir.glob('*.txt')):
    sources.setdefault(f.name.split('.')[0], []).append(toks_src(f.read_text(encoding='utf8')))
for path in sys.argv[2:]:
    sources['OWN:' + Path(path).stem] = [toks_src(Path(path).read_text(encoding='utf8', errors='ignore'))]

N = 8
index = defaultdict(set)
for key, docs in sources.items():
    for w in docs:
        for a in range(len(w) - N + 1):
            index[' '.join(w[a:a + N])].add(key)
grams4 = {k: {' '.join(w[a:a + 4]) for w in d for a in range(len(w) - 3)} for k, d in sources.items()}

# blocks labelled by chapter and section: Intro, Ch1 1.2.3, Concl, AppA; starred headings by name
marks, ch, num, appx, s, ss = [(0, 'Front')], '', 0, 0, 0, 0
for m in re.finditer(r'\\(unnumberedchapter|chapter|section|subsection)(\*?)\{([^}]*)\}', body):
    kind, star, title = m.groups()
    if star:
        if kind == 'chapter':
            marks.append((m.start(), title[:8]))
        continue
    if kind == 'unnumberedchapter':
        ch, s, ss = {'Introduction': 'Intro'}.get(title, 'Concl' if 'Conclusion' in title else title[:8]), 0, 0
    elif kind == 'chapter':
        if m.start() >= start_app:
            appx += 1; ch = 'App' + 'ABCDEFGHIJ'[appx - 1]
        else:
            num += 1; ch = f'Ch{num}'
        s = ss = 0
    elif kind == 'section':
        s += 1; ss = 0
    else:
        ss += 1
    sec = f' {num}.{s}' + (f'.{ss}' if ss else '') if ch.startswith('Ch') and s else ''
    marks.append((m.start(), ch + sec))

blocks, pos = [], 0
for block in re.split(r'\n\s*\n', body):
    sec = [n for p, n in marks if p <= pos][-1]
    pos += len(block) + 2
    for part in (re.split(r'\\\\', block) if block.count('&') >= 3 else [block]):
        if len(toks(part)) >= 12:
            blocks.append((sec, part))

STOP = set('the of and in to a for with on by at is are was were as an or from that this be which it not its their than'.split())
runs, close = [], []
total, covered, covered_ext = 0, 0, 0
per_source = defaultdict(int)
for sec, block in blocks:
    w = toks(block)
    total += len(w)
    cited = {k.strip() for g in CITE.findall(block) for k in g.split(',')}
    mark, mark_ext = [False] * len(w), [False] * len(w)
    a = 0
    while a <= len(w) - N:
        g = ' '.join(w[a:a + N])
        if g in index:
            keys = set(index[g]); b = a + N
            while b < len(w) and ' '.join(w[b - N + 1:b + 1]) in index:
                keys = (keys & index[' '.join(w[b - N + 1:b + 1])]) or keys
                b += 1
            ext = any(not k.startswith('OWN:') for k in keys)
            for i in range(a, b):
                mark[i] = True
                mark_ext[i] = mark_ext[i] or ext
            for k in keys:
                per_source[k] += b - a
            runs.append((b - a, sec, sorted(keys), bool(cited & keys), ' '.join(w[a:b])))
            a = b
        else:
            a += 1
    covered += sum(mark)
    covered_ext += sum(mark_ext)
    g4 = [' '.join(w[i:i + 4]) for i in range(len(w) - 3)]
    g4 = [g for g in g4 if sum(x not in STOP and not x.replace('.', '').isdigit() for x in g.split()) >= 2]
    for k in cited & set(grams4):
        if len(g4) >= 15:
            close.append((sum(g in grams4[k] for g in g4) / len(g4), sec, k, len(w), ' '.join(w[:12])))

print(f'sources: {len(sources)} texts; thesis: {len(blocks)} blocks, {total} words')
print(f'words inside verbatim runs of >= {N} words: {covered} ({100 * covered / total:.2f}%); '
      f'with a published source: {covered_ext} ({100 * covered_ext / total:.2f}%)')
print('\n== words matched per source')
for k, v in sorted(per_source.items(), key=lambda x: -x[1])[:25]:
    print(f'{v:5d}  {k}')
runs.sort(reverse=True)
print(f'\n== verbatim runs of >= {N} words: {len(runs)} ("cites": the paragraph cites that source)')
for L, sec, keys, cites, txt in runs[:60]:
    print(f'{L:3d} w  {sec:12s} {",".join(keys)[:34]:34s} {"cites" if cites else "     "} "{txt[:180]}"')
close.sort(reverse=True)
print(f'\n== close paraphrase: share of 4-word sequences shared with the cited source (top 30 of {len(close)})')
for share, sec, k, n, head in close[:30]:
    print(f'{100 * share:5.1f}%  {sec:12s} {k:20s} ({n:4d} words)  "{head}..."')
