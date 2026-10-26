"""Words, tables, figures per sub-subsection, largest first, with an estimated page count."""
import re
t = open('memoire_restructure.tex', encoding='utf8').read()
body = t[t.index(r'\chapter{General Introduction}'):t.index(r'\printbibliography')]
body = re.sub(r'(?<!\\)%.*', '', body)
total_pages = 99

def nwords(x):
    x = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', ' ', x, flags=re.S)
    x = re.sub(r'\\(label|cref|Cref|parencite|textcite|Textcite|ref)\{[^}]*\}', ' X ', x)
    x = re.sub(r'\\[a-zA-Z]+\*?', ' ', x)
    return len(re.findall(r'[A-Za-z][A-Za-z\-]+', x))

c = s = ss = sss = 0
units = []
cur = None
for piece in re.split(r'(\\(?:chapter|section|subsection|subsubsection)\{[^}]*\})', body):
    m = re.match(r'\\(chapter|section|subsection|subsubsection)\{([^}]*)\}', piece)
    if m:
        lvl, name = m.groups()
        if lvl == 'chapter': c += 1; s = ss = sss = 0
        elif lvl == 'section': s += 1; ss = sss = 0
        elif lvl == 'subsection': ss += 1; sss = 0
        else: sss += 1
        cur = [f'{c}.{s}.{ss}.{sss}', name, 0, 0, 0, 0]
        units.append(cur)
        continue
    if cur is None: continue
    cur[2] += nwords(piece)
    cur[3] += piece.count(r'\begin{table}')
    cur[4] += piece.count(r'\begin{figure}')
    cur[5] += len(re.findall(r'\\begin\{(equation|gather|align)\*?\}', piece))
tot = sum(u[2] for u in units)
# a float costs roughly a third of a page; prose about 380 words a page
def est(u):
    return u[2] / 380 + 0.35 * (u[3] + u[4])
scale = total_pages / sum(est(u) for u in units)
print(f'{len(units)} units, {tot} words')
for u in sorted(units, key=est, reverse=True)[:45]:
    print(f'{est(u)*scale:4.1f} p  {u[2]:5d} w  T{u[3]} F{u[4]} E{u[5]}  {u[0]:9s} {u[1][:70]}')
