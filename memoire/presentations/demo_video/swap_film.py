"""Replaces the video (and its poster frame) on the demonstration slide of a deck, touching
nothing else, so edits made to the deck in PowerPoint are kept.

    python swap_film.py ../TeleMonitor_defence_20min.pptx [out.pptx]
"""
import sys
from pathlib import Path

from pptx import Presentation

HERE = Path(__file__).parent
FILM = HERE / "out" / "TeleMonitor_film.mp4"
POSTER = HERE / "out" / "film_poster.png"
RT_MEDIA = ("http://schemas.microsoft.com/office/2007/relationships/media",
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships/video")
RT_IMAGE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

deck = Path(sys.argv[1])
out = Path(sys.argv[2]) if len(sys.argv) > 2 else deck
prs = Presentation(str(deck))
done = 0
for n, slide in enumerate(prs.slides, 1):
    pics = [sh for sh in slide.shapes if sh._element.xpath(".//a:videoFile")]
    if not pics:
        continue
    media = {r.target_part for r in slide.part.rels.values() if r.reltype in RT_MEDIA and not r.is_external}
    for part in media:
        part._blob = FILM.read_bytes()
    for pic in pics:
        rid = pic._element.xpath(".//a:blip/@r:embed")[0]
        slide.part.related_part(rid)._blob = POSTER.read_bytes()
    print(f"slide {n}: {len(media)} media part(s) replaced with {FILM.name} ({FILM.stat().st_size / 1e6:.1f} MB)")
    done += 1
if not done:
    raise SystemExit("no video found")
prs.save(str(out))
print("saved", out)
