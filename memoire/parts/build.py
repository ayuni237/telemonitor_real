"""Assemble memoire_restructure.tex from parts/ (page design: preamble.tex).

    python parts/build.py
    pdflatex memoire_restructure ; biber memoire_restructure ; pdflatex ×2

Order of the thesis, on the model of the NHPSD MSc thesis of Gwade (2025): front matter,
unnumbered introduction, four chapters, unnumbered conclusion, references, appendices.
A file listed here and absent is skipped, so a chapter can be added when it is written.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PARTS = ROOT / 'parts'

BODY = ['01_introduction.tex', '02_review.tex', '03_framework.tex', '04_methodology.tex',
        '05_results.tex', '06_conclusion.tex']
APPENDICES = ['07_appendices.tex']


def read(name: str) -> str:
    p = PARTS / name
    return p.read_text(encoding='utf8') if p.exists() else f'% {name}: not written yet\n'


out = [read('preamble.tex'), r'\begin{document}', read('00_front.tex')]
out += [read(n) for n in BODY]
out.append(r"""
\cleardoublepage
\phantomsection\addcontentsline{toc}{chapter}{References}
\markboth{References}{References}\markright{References}
\printbibliography[title={References}]
""")
appendix = [read(n) for n in APPENDICES if (PARTS / n).exists()]
if appendix:
    out.append(r'\appendix\crefalias{chapter}{appendix}')
    out += appendix
out.append(r'\end{document}')
text = '\n\n'.join(out) + '\n'
(ROOT / 'memoire_restructure.tex').write_text(text, encoding='utf8')
print('written', len(text.split('\n')), 'lines')
