# Thesis checks

Run these scripts from the `memoire/` folder, after `python parts/build.py` and a compilation (`pdflatex`, `biber`, `pdflatex` ×2), since they read `memoire_restructure.tex` and `memoire_restructure.toc`.

| Script | What it measures |
|---|---|
| `python tools/check_length.py` | pages, prose words, words in tables, number of tables, figures and equations, per chapter and per section |
| `python tools/check_length_detail.py` | the longest sub-subsections, with an estimate in pages |
| `python tools/check_redundancy.py` | paragraphs and sentences that say the same thing in different sections; repeated seven-word phrases |
| `python tools/check_repeated_ideas.py` | where each key idea or figure recurs (section numbers) |
| `python tools/fetch_sources.py references.bib tools/sources` | downloads, for every reference with a DOI, the abstract (Europe PMC or Crossref) and the full text when it is open access in PubMed Central (≈ 3 min) |
| `python tools/check_sources.py tools/sources` | word sequences of 8 or more words identical to a source; share of each paragraph's four-word sequences taken from the source it cites |

The folder `tools/sources/` holds copyrighted article texts: it is excluded from git.

These checks do not replace the school's plagiarism software (Compilatio, Turnitin), which also compares the text with the web and with other theses, and detects text written with AI tools.
