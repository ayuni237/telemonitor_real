"""Assemble memoire_restructure.tex: front matter of final_memoire.tex + chapters in parts/."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PARTS = ROOT / 'parts'
SRC = (ROOT / 'final_memoire.tex').read_text(encoding='utf8').split('\n')

# preamble, title page and table of contents (up to the \clearpage after \tableofcontents)
front = '\n'.join(SRC[:SRC.index(r'\tableofcontents') + 2])
# IEEE style, as the school plan requires: numbered in order of first citation
front = front.replace(r'\usepackage[backend=biber,style=ieee,sorting=nyt]{biblatex}',
                      r'\usepackage[backend=biber,style=ieee,sorting=none]{biblatex}' + '\n' + r'\usepackage{longtable}')

# drop the drafting helpers (\verify, \bq), no longer used
lines = front.split('\n')
start = lines.index('% ===================== Drafting helpers =====================')
end = next(i for i in range(start, len(lines)) if lines[i].startswith(r'\newcommand{\bq}'))
front = '\n'.join(lines[:start] + lines[end + 1:])

# front matter in roman numerals: contents, then lists of figures, tables, abbreviations and symbols
front = front.replace('\\tableofcontents', '\\pagenumbering{roman}\n\\tableofcontents', 1)
front += '\n' + (PARTS / 'front_lists.tex').read_text(encoding='utf8')

chapters = ['ch1_intro.tex', 'ch2_litreview.tex', 'ch3_methodology.tex', 'ch4_design.tex']
body = '\n\n'.join((PARTS / c).read_text(encoding='utf8') for c in chapters)

back = r"""
%==========================================================================
% BIBLIOGRAPHY
%==========================================================================
\printbibliography[heading=bibintoc,title={References}]

""" + (PARTS / 'appendix_tripod.tex').read_text(encoding='utf8') + r"""

\end{document}
"""

out = front + '\n\n' + body + '\n' + back
(ROOT / 'memoire_restructure.tex').write_text(out, encoding='utf8')
print('written', len(out.split('\n')), 'lines')
