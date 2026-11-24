"""Builds the 20-minute defence deck from TeleMonitor_defence_final.pptx (left untouched).

- removes slides 2, 4, 18, 21, 29
- merges theory 8+9 and 10+11 (core diagram of each kept, side panels dropped; notes appended)
- turns slide 22 into the demo slide (video), placed before the conclusion
"""
import copy
import sys
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Inches, Pt

SRC = Path(r"C:\Projects\memoire\presentations\TeleMonitor_defence_final.pptx")
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else r"C:\Projects\memoire\presentations\TeleMonitor_defence_20min.pptx")
VIDEO = Path(r"C:\Projects\memoire\presentations\demo_video\out\TeleMonitor_film.mp4")
POSTER = Path(__file__).parent / "out" / "film_poster.png"
E = 914400
NAVY, INK, GREY = RGBColor(0x12, 0x35, 0x5B), RGBColor(0x16, 0x16, 0x16), RGBColor(0x5A, 0x63, 0x6E)

prs = Presentation(str(SRC))
S = list(prs.slides)                       # S[n - 1] is slide n
A_NS = "{http://schemas.openxmlformats.org/drawingml/2006/main}"


def inch(v): return v / E


def content(slide):
    """Shapes below the title, the slide-number placeholder excluded."""
    return [sh for sh in slide.shapes if not sh.is_placeholder and inch(sh.top) >= 1.3]


def set_text(shape, text):
    """Replace a shape's text, keeping the first run's formatting."""
    tf = shape.text_frame
    p0 = tf.paragraphs[0]
    for p in tf.paragraphs[1:]:
        p._p.getparent().remove(p._p)
    runs = p0.runs
    runs[0].text = text
    for r in runs[1:]:
        r._r.getparent().remove(r._r)


def header_title(slide, header, title):
    ph = [sh for sh in slide.shapes if sh.is_placeholder and inch(sh.top) < 1.3]
    ph.sort(key=lambda sh: sh.top)
    set_text(ph[0], header)
    set_text(ph[1], title)


def remove(shape):
    el = shape._element
    for blip in el.iter(A_NS + "blip"):    # drop the picture's relationship with it
        rid = blip.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed")
        el.getparent().remove(el)
        shape.part.drop_rel(rid)
        return
    el.getparent().remove(el)


def move(shape, x=None, y=None, w=None, h=None):
    if x is not None: shape.left = Inches(x)
    if y is not None: shape.top = Inches(y)
    if w is not None: shape.width = Inches(w)
    if h is not None: shape.height = Inches(h)


def scale(shape, x0, y0, nx0, ny0, k, keep_h=False):
    """Scale a shape about (x0, y0) by k, landing at (nx0, ny0); fonts are kept."""
    x, y, w, h = inch(shape.left), inch(shape.top), inch(shape.width), inch(shape.height)
    nh = h if keep_h else h * k
    cy = ny0 + (y + h / 2 - y0) * k
    move(shape, nx0 + (x - x0) * k, cy - nh / 2, w * k, nh)


def copy_into(target, shapes):
    """Deep-copy shapes into target with fresh ids; returns the new python-pptx shapes."""
    tree = target.shapes._spTree
    used = {int(e.get("id")) for e in tree.iter() if e.tag.endswith("}cNvPr")}
    nxt = max(used) + 1
    idmap, els = {}, []
    for sh in shapes:
        el = copy.deepcopy(sh._element)
        for c in el.iter():
            if c.tag.endswith("}cNvPr"):
                idmap[c.get("id")] = str(nxt)
                c.set("id", str(nxt))
                nxt += 1
        assert "r:embed" not in str(el.xml) and 'r:id="' not in str(el.xml), "shape with a relationship"
        tree.insert_element_before(el, "p:extLst")
        els.append(el)
    for el in els:                          # connectors keep pointing at the copied shapes
        for c in el.iter():
            if c.tag in (A_NS + "stCxn", A_NS + "endCxn"):
                if c.get("id") in idmap:
                    c.set("id", idmap[c.get("id")])
                else:
                    c.getparent().remove(c)
    return [sh for sh in target.shapes if sh._element in els]


def append_notes(dst, src):
    body = dst.notes_slide.notes_text_frame._txBody
    for p in src.notes_slide.notes_text_frame._txBody.findall(A_NS + "p"):
        body.append(copy.deepcopy(p))


# ---------- slide 7: pointer to the theory slides ----------
for sh in S[6].shapes:
    if sh.has_text_frame:
        for p in sh.text_frame.paragraphs:
            for r in p.runs:
                if "next four slides" in r.text:
                    r.text = r.text.replace("next four slides", "next two slides")

# ---------- theory 1 of 2 = slide 8 + slide 9 ----------
s8, s9 = S[7], S[8]
header_title(s8, "2 · PROPOSED SOLUTION · THEORY 1 OF 2", "A sourced label, forecast so that it cannot leak")
caption = None
for sh in content(s8):
    x, y = inch(sh.left), inch(sh.top)
    if x >= 7.9:                                            # "Construction of the label" column
        if sh.has_text_frame and sh.text_frame.text.startswith("Glucose not measured"):
            caption = sh
        else:
            remove(sh)
    elif y < 1.8:                                           # legend: pitch 1.75 -> 1.55
        square = sh.width < Inches(0.5)
        i = round((x - (0.60 if square else 0.95)) / 1.75)
        move(sh, x=0.60 + i * 1.55 + (0 if square else 0.35), w=None if square else 1.15)
    elif sh.has_table:
        tbl = sh.table
        for col, w in zip(tbl.columns, (1.10, 3.00, 2.25)):
            col.width = Inches(w)
        move(sh, w=6.35)
    elif x >= 1.8:                                          # threshold bars and their ticks
        k = 5.0 / 5.5
        w = inch(sh.width)
        if sh.has_text_frame and sh.text_frame.text.strip():  # tick: move its centre
            cx = 1.95 + (x + w / 2 - 1.95) * k
            move(sh, x=cx - w / 2)
        else:
            move(sh, x=1.95 + (x - 1.95) * k, w=w * k)
set_text(caption, "Worst channel governs; glucose not measured → no glycaemic label, never “stable”")
move(caption, x=0.60, y=6.20, w=6.35, h=0.55)

src9 = [sh for sh in content(s9) if inch(sh.left) < 7.0]  # (a)/(b) diagram and the "Sample" panel
geo = [(inch(sh.top), inch(sh.height), sh.text_frame.text.strip() if sh.has_text_frame else "") for sh in src9]
k = 5.43 / 6.35
for sh, (y, h, t) in zip(copy_into(s8, src9), geo):
    if y >= 5.25:                                           # "Sample" panel: full width, height kept
        if not t:
            move(sh, x=7.30, y=4.80, w=5.43, h=1.80)
        elif t.startswith("Sample"):
            move(sh, x=7.40, y=4.86, w=5.25)
        else:
            move(sh, x=7.40, y=5.36, w=5.25, h=1.35)
    else:
        scale(sh, 0.60, 1.40, 7.30, 1.40, k, keep_h=bool(t) and h > 0.5)
        if t == "input window, length L":                   # narrower window: shorter label
            set_text(sh, "window, length L")
        elif t == "embargo ε":
            sh.left += Inches(0.12)
append_notes(s8, s9)

# ---------- theory 2 of 2 = slide 10 + slide 11 ----------
s10, s11 = S[9], S[10]
header_title(s10, "2 · PROPOSED SOLUTION · THEORY 2 OF 2", "The rule is the floor; at home, a two-stage triage")
why = None
for sh in content(s10):
    if inch(sh.left) >= 8.3:                                # "Why the rule is the floor" panel
        if sh.has_text_frame and sh.text_frame.text.startswith("A patient at"):
            why = sh
        else:
            remove(sh)
    else:
        scale(sh, 0.60, 1.70, 0.60, 1.55, 6.25 / 7.40)
paras = why.text_frame.paragraphs                           # keep the first and the "fails" bullet
keep = [p for p in paras if p.text.startswith("A patient at") or "fails" in p.text]
for p in paras:
    if p not in keep:
        p._p.getparent().remove(p._p)
move(why, x=0.60, y=5.85, w=6.25, h=1.05)
copy_into(s10, [sh for sh in content(s11) if inch(sh.left) >= 7.1])
append_notes(s10, s11)

# ---------- demo slide (slide 22 reused) ----------
s22 = S[21]
header_title(s22, "6 · ASSESSMENT · DEMONSTRATION", "TeleMonitor in use: patient and clinician")
for sh in content(s22):
    remove(sh)
vh = 5.2
vw = vh * 16 / 9
s22.shapes.add_movie(str(VIDEO), Inches(0.60), Inches(1.45), Inches(vw), Inches(vh),
                     poster_frame_image=str(POSTER), mime_type="video/mp4")
x = 0.60 + vw + 0.35
box = s22.shapes.add_textbox(Inches(x), Inches(1.45), Inches(12.73 - x), Inches(4.2))
tf = box.text_frame
tf.word_wrap = True
items = [("The loop, end to end", True, 17, NAVY)] + [
    (t, False, 14, INK) for t in (
        "1  The patient enters a reading at home",
        "2  The phone grades it at once, even offline",
        "3  The model may raise the level, never lower it",
        "4  The clinician reviews the queue, records a verdict and replies",
        "5  The patient is notified")]
for i, (t, bold, size, color) in enumerate(items):
    p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
    p.space_after = Pt(9)
    r = p.add_run()
    r.text, r.font.bold, r.font.size, r.font.color.rgb = t, bold, Pt(size), color
note = s22.shapes.add_textbox(Inches(x), Inches(5.75), Inches(12.73 - x), Inches(1.15))
note.text_frame.word_wrap = True
r = note.text_frame.paragraphs[0].add_run()
r.text = "2 min · English voice, French subtitles. Screens: real recordings of the app with invented demo accounts. Human scenes: AI-generated illustrations."
r.font.size, r.font.color.rgb = Pt(12), GREY
nb = s22.notes_slide.notes_text_frame
nb.text = ("Before concluding, here is TeleMonitor in use. [Play the video.] "
           "It follows one reading through the whole loop: the patient enters it at home, the phone grades it "
           "against the home thresholds at once, even offline, the model may raise the level but never lower it, "
           "the red alert goes to the top of the clinician's queue, the clinician records a verdict and writes "
           "to the patient, and the patient is notified. The screens are real recordings of the app with invented "
           "demo accounts; the human scenes are AI-generated illustrations and are labelled as such. The voice is in English with French subtitles; the film lasts two minutes.")

# ---------- order: drop 2, 4, 9, 11, 18, 21, 29; demo before the conclusion ----------
order = [1, 3, 5, 6, 7, 8, 10, 12, 13, 14, 15, 16, 17, 19, 20, 23, 24, 25, 26, 27, 28, 30, 22, 31, 32]
lst = prs.slides._sldIdLst
ids = list(lst)
for n, el in enumerate(ids, 1):
    lst.remove(el)
    if n not in order:
        prs.part.drop_rel(el.rId)
for n in order:
    lst.append(ids[n - 1])

prs.save(str(OUT))
print(OUT, len(prs.slides), "slides")
