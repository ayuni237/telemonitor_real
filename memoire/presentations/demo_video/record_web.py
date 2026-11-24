"""Records the clinician's web takes headless: Chrome driven by Playwright, frames captured from
the browser itself (no screen capture, nothing else of the PC can appear).

    python record_web.py dry      # queue -> Esther's record -> verdict sheet opened, nothing saved
    python record_web.py c1       # queue -> record -> verdict "True alert", "Consultation", comment, close

Writes rec/<take>.mp4 (2560 x 1440, 30 fps) and rec/<take>.json (time of each step).
The web build must be served on http://localhost:5000 (scratchpad serve_web.py).
"""
import asyncio
import base64
import json
import subprocess
import sys
import time
from pathlib import Path

from playwright.async_api import async_playwright

HERE = Path(__file__).parent
SECRETS = Path(r"C:\Projects\telemonitor-research\secrets\demo_accounts.txt")
URL = "http://localhost:5000/"
VIEW = {"width": 1280, "height": 720}
DPR = 2
COMMENT = "Please come to the health centre tomorrow morning. I have told the nurse."

CURSOR = """
window.addEventListener('DOMContentLoaded', () => {
  const c = document.createElement('div');
  c.style.cssText = 'position:fixed;left:0;top:0;width:26px;height:26px;z-index:2147483647;pointer-events:none;transform:translate(-200px,-200px);';
  c.innerHTML = '<svg width="26" height="26" viewBox="0 0 24 24"><path d="M4 2l6.5 18 2.6-7.4L20.5 10z" fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>';
  const ring = document.createElement('div');
  ring.style.cssText = 'position:fixed;left:0;top:0;width:40px;height:40px;margin:-20px 0 0 -20px;border-radius:50%;border:3px solid rgba(18,53,91,.75);z-index:2147483646;pointer-events:none;opacity:0;';
  document.documentElement.append(ring, c);
  window.addEventListener('pointermove', e => { c.style.transform = `translate(${e.clientX - 3}px, ${e.clientY - 2}px)`; }, true);
  window.addEventListener('pointerdown', e => {
    ring.style.transition = 'none'; ring.style.left = e.clientX + 'px'; ring.style.top = e.clientY + 'px';
    ring.style.opacity = '1'; ring.style.transform = 'scale(0.5)';
    requestAnimationFrame(() => requestAnimationFrame(() => {
      ring.style.transition = 'opacity .5s ease-out, transform .5s ease-out'; ring.style.opacity = '0'; ring.style.transform = 'scale(1.5)';
    }));
  }, true);
});
"""

FIND = """(text) => {
  const all = [...document.querySelectorAll('flt-semantics, input, textarea')];
  const hits = all.filter(e => {
    const s = ((e.getAttribute('aria-label') || '') + ' ' + (e.innerText || '')).trim();
    const r = e.getBoundingClientRect();
    return s.includes(text) && r.width > 0 && r.height > 0;
  }).map(e => e.getBoundingClientRect()).sort((a, b) => a.width * a.height - b.width * b.height);
  return hits.length ? [hits[0].x + hits[0].width / 2, hits[0].y + hits[0].height / 2] : null;
}"""


class Recorder:
    def __init__(self, ctx, page, folder: Path):
        self.ctx, self.page, self.dir = ctx, page, folder
        self.frames: list[tuple[float, Path]] = []
        self.marks: list[tuple[str, float]] = []

    async def start(self):
        self.dir.mkdir(parents=True, exist_ok=True)
        self.cdp = await self.ctx.new_cdp_session(self.page)
        self.cdp.on("Page.screencastFrame", self._frame)
        await self.cdp.send("Page.startScreencast", {"format": "jpeg", "quality": 92, "maxWidth": 2560, "maxHeight": 1440})
        self.t0 = time.monotonic()
        self.wall0 = time.time()

    def _frame(self, params):
        p = self.dir / f"f{len(self.frames):05d}.jpg"
        p.write_bytes(base64.b64decode(params["data"]))
        self.frames.append((time.monotonic(), p))
        asyncio.ensure_future(self.cdp.send("Page.screencastFrameAck", {"sessionId": params["sessionId"]}))

    def mark(self, what: str):
        self.marks.append((what, round(time.monotonic() - self.t0, 2)))
        print(f"{self.marks[-1][1]:7.2f}  {what}", flush=True)

    async def stop(self):
        await asyncio.sleep(0.3)
        await self.cdp.send("Page.stopScreencast")
        self.t1 = time.monotonic()

    def save(self, out: Path):
        lst = self.dir / "list.txt"
        lines = ["ffconcat version 1.0"]
        frames = [(t, p) for t, p in self.frames if t >= self.t0]
        for (t, p), nxt in zip(frames, [*frames[1:], (self.t1, None)]):
            lines += [f"file '{p.as_posix()}'", f"duration {max(nxt[0] - t, 0.001):.4f}"]
        lines.append(f"file '{frames[-1][1].as_posix()}'")
        lst.write_text("\n".join(lines) + "\n", encoding="utf-8")
        ff = subprocess.run([sys.executable, "-c", "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"],
                            capture_output=True, text=True).stdout.strip()
        subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                        "-fps_mode", "cfr", "-r", "30", "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p", str(out)], check=True)
        out.with_suffix(".json").write_text(json.dumps({**dict(self.marks), "wallclock_start": self.wall0}, indent=1), encoding="utf-8")
        print(out, f"{self.t1 - self.t0:.1f} s, {len(frames)} frames")


class Web:
    def __init__(self, page):
        self.page = page
        self.x, self.y = 640, 360

    async def where(self, text: str, tries: int = 12):
        for _ in range(tries):
            xy = await self.page.evaluate(FIND, text)
            if xy:
                return xy
            await asyncio.sleep(0.5)
        raise LookupError(f"not on screen: {text!r}")

    async def move(self, x: float, y: float, ms: int = 700):
        steps = max(8, ms // 16)
        x0, y0 = self.x, self.y
        for i in range(1, steps + 1):
            p = i / steps
            e = p * p * (3 - 2 * p)                          # ease in-out
            await self.page.mouse.move(x0 + (x - x0) * e, y0 + (y - y0) * e)
            await asyncio.sleep(ms / steps / 1000)
        self.x, self.y = x, y

    async def click(self, text: str, pause: float = 0.6, dx: float = 0, dy: float = 0):
        x, y = await self.where(text)
        await self.move(x + dx, y + dy)
        await asyncio.sleep(0.25)
        await self.page.mouse.click(x + dx, y + dy)
        await asyncio.sleep(pause)

    async def type(self, text: str, delay: int = 45):
        await self.page.keyboard.type(text, delay=delay)

    async def scroll(self, dy: int, steps: int = 12):
        for _ in range(steps):
            await self.page.mouse.wheel(0, dy / steps)
            await asyncio.sleep(0.05)


async def sign_in(page, web: Web):
    pw = [line.split("\t")[1].strip() for line in SECRETS.read_text(encoding="utf-8").splitlines()
          if line.startswith("paul.ndoumbe@example.com\t")][-1]
    await page.goto(URL, wait_until="load")
    for _ in range(40):                           # Flutter starts, then its semantics tree is switched on
        await asyncio.sleep(1)
        await page.evaluate("() => { const e = document.querySelector('flt-semantics-placeholder'); if (e) e.click(); }")
        if await page.locator("input").count() >= 2:
            break
    else:
        await page.screenshot(path=str(HERE / "rec" / "_signin_failed.png"))
        raise RuntimeError("sign-in page did not appear")
    await asyncio.sleep(0.5)
    for i, text in enumerate(("paul.ndoumbe@example.com", pw)):     # the two inputs: email, password
        box = await page.locator("input").nth(i).bounding_box()
        await page.mouse.click(box["x"] + 200, box["y"] + box["height"] / 2)
        await asyncio.sleep(0.4)
        await web.type(text, 10)
    await web.click("Sign In", 6)
    await page.evaluate("() => { const e = document.querySelector('flt-semantics-placeholder'); if (e) e.click(); }")
    await asyncio.sleep(1.5)


async def chat(page, web: "Web", rec: "Recorder"):
    """C2: the clinician writes to Esther from her record."""
    rec.mark("patients")
    await asyncio.sleep(1.0)
    await web.click("Patients", 1.5)
    await web.click("Esther Mbella", 2.5)
    rec.mark("record")
    await web.click("Message patient", 2.2)
    rec.mark("chat")
    await web.click("Type a message", 0.5)
    await web.type(COMMENT, 42)
    await asyncio.sleep(0.6)
    rec.mark("send")
    await page.keyboard.press("Enter")
    rec.mark("sent")
    await asyncio.sleep(4.0)


async def take(name: str):
    async with async_playwright() as p:
        b = await p.chromium.launch(channel="chrome", headless=True)
        ctx = await b.new_context(viewport=VIEW, device_scale_factor=DPR, color_scheme="light", locale="en-GB")
        await ctx.add_init_script(CURSOR)
        page = await ctx.new_page()
        web = Web(page)
        await sign_in(page, web)
        await web.move(640, 420, 300)
        await page.screenshot(path=str(HERE / "rec" / f"_{name}_start.png"))
        rec = Recorder(ctx, page, HERE / "rec" / f"_{name}_frames")
        await rec.start()
        if name == "c2":
            await chat(page, web, rec)
            await rec.stop()
            await b.close()
            rec.save(HERE / "rec" / f"{name}.mp4")
            return
        rec.mark("queue")
        await asyncio.sleep(2.5)
        q = await web.where("Queue")
        first = await page.evaluate("() => { const g = [...document.querySelectorAll('flt-semantics[role=group]')].filter(e => e.innerText.includes('Verdict')); const r = g.length ? g[0].getBoundingClientRect() : null; return r ? [r.x + 260, r.y + 60] : null; }")
        if first:
            await web.move(*first, 900)
        await asyncio.sleep(1.5)
        rec.mark("patients tab")
        await web.click("Patients", 1.5)
        rec.mark("open Esther")
        await web.click("Esther Mbella", 2.8)
        rec.mark("record")
        await web.move(640, 450, 500)
        await web.scroll(380, 18)
        await asyncio.sleep(3.0)
        rec.mark("back to queue")
        await page.go_back()
        await asyncio.sleep(1.0)
        await web.click("Queue", 1.2)
        rec.mark("verdict")
        await web.click("Verdict", 1.2)
        await web.click("True alert", 0.6)
        await web.click("Consultation", 0.6)
        rec.mark("comment")
        await web.click("Comment", 0.4)
        await web.type(COMMENT, 38)
        await asyncio.sleep(0.5)
        box = await page.evaluate("() => { const e = document.querySelector('flt-semantics[role=checkbox], input[type=checkbox]'); const r = e && e.getBoundingClientRect(); return r ? [r.x + r.width / 2, r.y + r.height / 2] : null; }")
        if box is None:                                   # the row itself, its box at the right end
            x, y = await web.where("Send the comment")
            box = [x + 545, y]
        await web.move(*box)
        await asyncio.sleep(0.2)
        await page.mouse.click(*box)
        await asyncio.sleep(0.8)
        rec.mark("ticked")
        if name == "c1":
            rec.mark("close")
            await web.click("Close the alert", 2.5)
            rec.mark("closed")
            await asyncio.sleep(2.5)
        else:
            await asyncio.sleep(2.0)
        await rec.stop()
        await b.close()
    rec.save(HERE / "rec" / f"{name}.mp4")


if __name__ == "__main__":
    asyncio.run(take(sys.argv[1] if len(sys.argv) > 1 else "dry"))
