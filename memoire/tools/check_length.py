"""Length of the thesis by chapter and section: pages, prose words, table words, floats, equations."""
import re

t = open('memoire_restructure.tex', encoding='utf8').read()
body = t[t.index(r'\chapter{General Introduction}'):t.index(r'\printbibliography')]
toc = open('memoire_restructure.toc', encoding='utf8').read()

def nwords(x):
    x = re.sub(r'(?<!\\)%.*', '', x)
    x = re.sub(r'\\(label|cref|Cref|parencite|textcite|Textcite|ref)\{[^}]*\}', ' X ', x)
    x = re.sub(r'\\[a-zA-Z]+\*?', ' ', x)
    return len(re.findall(r'[A-Za-z][A-Za-z\-]+', x))

def split_kinds(x):
    """prose words, table words, number of tables, figures, display equations"""
    tikz = re.findall(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', x, flags=re.S)
    x2 = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', ' ', x, flags=re.S)
    tables = re.findall(r'\\begin\{(?:tabularx|tabular|longtable)\}.*?\\end\{(?:tabularx|tabular|longtable)\}', x2, flags=re.S)
    x3 = re.sub(r'\\begin\{(tabularx|tabular|longtable)\}.*?\\end\{(tabularx|tabular|longtable)\}', ' ', x2, flags=re.S)
    eqs = len(re.findall(r'\\begin\{(equation|gather|align)\*?\}', x))
    return nwords(x3), sum(nwords(tb) for tb in tables), x.count(r'\begin{table}'), x.count(r'\begin{figure}'), eqs

# page of each chapter / section from the toc
pages = re.findall(r'\\contentsline \{(chapter|section)\}\{(?:\\numberline \{([^}]*)\})?(.*?)\}\{(\d+)\}', toc)
pg = {}
seq = [(lvl, num, ttl, int(p)) for lvl, num, ttl, p in pages if p.isdigit()]
for k, (lvl, num, ttl, p) in enumerate(seq):
    nxt = next((q for l2, n2, t2, q in seq[k + 1:] if lvl == 'section' or l2 == 'chapter'), None)
    pg[(lvl, num)] = (p, (nxt - p) if nxt else None)

parts = re.split(r'(\\chapter\{[^}]*\}|\\section\{[^}]*\})', body)
chap_i = 0; sec_i = 0
rows = []
for i in range(1, len(parts), 2):
    head, txt = parts[i], parts[i + 1]
    name = re.sub(r'\\(chapter|section)\{|\}', '', head)
    if head.startswith(r'\chapter'):
        chap_i += 1; sec_i = 0; key = ('chapter', str(chap_i))
    else:
        sec_i += 1; key = ('section', f'{chap_i}.{sec_i}')
    rows.append((key, name, *split_kinds(txt)))

tot_prose = sum(r[2] for r in rows); tot_tab = sum(r[3] for r in rows)
print(f'TOTAL prose words {tot_prose}, table words {tot_tab}, tables {sum(r[4] for r in rows)}, '
      f'figures {sum(r[5] for r in rows)}, display equations {sum(r[6] for r in rows)}')
print()
print(' pages  prose  tables(words) T  F  Eq  section')
chap = None
agg = {}
for key, name, pr, tw, nt, nf, ne in rows:
    p, span = pg.get(key, (None, None))
    if key[0] == 'chapter':
        chap = key[1]
    a = agg.setdefault(chap, [0, 0, 0, 0, 0]); a[0] += pr; a[1] += tw; a[2] += nt; a[3] += nf; a[4] += ne
    ind = '' if key[0] == 'chapter' else '   '
    print(f'{(span or 0):5d} {pr:6d} {tw:7d}      {nt:2d} {nf:2d} {ne:3d}  {ind}{key[1]} {name[:55]}')
print()
for c, (pr, tw, nt, nf, ne) in agg.items():
    print(f'chapter {c}: prose {pr} words, table text {tw} words, {nt} tables, {nf} figures, {ne} equations')
