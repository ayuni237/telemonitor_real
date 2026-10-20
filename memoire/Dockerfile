# Thesis build: assembles memoire_restructure.tex from parts/ (build.py) and
# compiles it with pdfLaTeX + Biber (IEEE bibliography). The memoire folder is
# mounted at /doc, so the PDF is written next to the sources.
# texlive/texlive is the official TeX Live image (Island of TeX); full scheme.
FROM texlive/texlive:latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /doc
CMD ["bash", "-c", "python3 parts/build.py && pdflatex -interaction=nonstopmode memoire_restructure.tex >/dev/null && biber memoire_restructure && pdflatex -interaction=nonstopmode memoire_restructure.tex >/dev/null && pdflatex -interaction=nonstopmode memoire_restructure.tex | tail -n 3"]
