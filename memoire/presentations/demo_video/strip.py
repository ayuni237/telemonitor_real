"""1-fps contact sheet of a take: python strip.py rec/p1.mp4 out.png [start end step]"""
import subprocess, sys, tempfile
from pathlib import Path
from PIL import Image, ImageDraw
import imageio_ffmpeg
src, out = sys.argv[1], Path(sys.argv[2])
a, b, step = (float(x) for x in (sys.argv[3:6] if len(sys.argv) > 5 else (0, 999, 1)))
ff = imageio_ffmpeg.get_ffmpeg_exe()
tmp = Path(tempfile.mkdtemp())
subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-i", src, "-vf",
                f"fps=30,trim=start={a}:end={b},setpts=PTS-STARTPTS,fps=1/{step},scale=160:-1", str(tmp / "f%03d.png")], check=True)
fs = sorted(tmp.glob("f*.png"))
w, h = Image.open(fs[0]).size
cols = 15
sheet = Image.new("RGB", (w * cols, (h + 14) * ((len(fs) + cols - 1) // cols)), "white"); d = ImageDraw.Draw(sheet)
for i, f in enumerate(fs):
    x, y = (i % cols) * w, (i // cols) * (h + 14)
    sheet.paste(Image.open(f), (x, y + 14)); d.text((x + 3, y + 1), f"{a + i * step:g}", fill="black")
sheet.save(out)
print(len(fs), "frames")
