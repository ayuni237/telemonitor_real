"""For every cited work with a DOI: abstract (Europe PMC, else Crossref) and, when open
access in PMC, the full text. Saves one text file per work in the output folder."""
import json, re, sys, time, urllib.parse, urllib.request
from pathlib import Path

bib = open(sys.argv[1], encoding='utf8').read()
out = Path(sys.argv[2]); out.mkdir(exist_ok=True)
UA = {'User-Agent': 'thesis-similarity-check/1.0'}

def get(url, tries=3):
    for k in range(tries):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40).read()
        except Exception as e:
            time.sleep(4 * (k + 1))
    return None

def strip_xml(x):
    x = re.sub(r'<(ref-list|table-wrap|fig|back|front)\b.*?</\1>', ' ', x, flags=re.S)
    x = re.sub(r'<[^>]+>', ' ', x)
    return re.sub(r'\s+', ' ', x)

log = {}
for key, body in re.findall(r'@\w+\{([^,]+),(.*?)\n\}', bib, flags=re.S):
    m = re.search(r'doi\s*=\s*\{([^}]*)\}', body)
    if not m:
        continue
    doi = m.group(1).strip()
    if (out / f'{key}.full.txt').exists() or (out / f'{key}.abs.txt').exists():
        continue
    abstract, pmcid = '', None
    raw = get('https://www.ebi.ac.uk/europepmc/webservices/rest/search?query='
              + urllib.parse.quote(f'DOI:"{doi}"') + '&resultType=core&format=json')
    if raw:
        hits = json.loads(raw).get('resultList', {}).get('result', [])
        if hits:
            abstract = re.sub(r'<[^>]+>', ' ', hits[0].get('abstractText', '') or '')
            pmcid = hits[0].get('pmcid')
    if not abstract:
        raw = get('https://api.crossref.org/works/' + urllib.parse.quote(doi))
        if raw:
            abstract = re.sub(r'<[^>]+>', ' ', json.loads(raw)['message'].get('abstract', '') or '')
    full = ''
    if pmcid:
        raw = get(f'https://www.ebi.ac.uk/europepmc/webservices/rest/{pmcid}/fullTextXML')
        if raw:
            full = strip_xml(raw.decode('utf8', 'ignore'))
    if abstract:
        (out / f'{key}.abs.txt').write_text(abstract, encoding='utf8')
    if full:
        (out / f'{key}.full.txt').write_text(full, encoding='utf8')
    log[key] = (len(abstract.split()), len(full.split()), pmcid)
    print(f'{key:22s} abstract {len(abstract.split()):5d}  full {len(full.split()):6d}  {pmcid or ""}', flush=True)
    time.sleep(1.5)
