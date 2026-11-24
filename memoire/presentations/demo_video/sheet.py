"""Frame sheet of a take: python sheet.py rec/p1.mp4 out.png 3 8 15 ..."""
import subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw
import imageio_ffmpeg
src, out, ts = sys.argv[1], Path(sys.argv[2]), [float(t) for t in sys.argv[3:]]
ff = imageio_ffmpeg.get_ffmpeg_exe()
ims = []
for t in ts:
    p = out.with_name(f"_{t}.png")
    subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-vf", f"fps=30,trim=start={t},setpts=PTS-STARTPTS,scale=270:-1", "-frames:v", "1", str(p)], check=True)
    ims.append(Image.open(p))
w, h = ims[0].size
sheet = Image.new("RGB", (w * len(ims), h + 18), "white"); d = ImageDraw.Draw(sheet)
for i, (t, im) in enumerate(zip(ts, ims)):
    sheet.paste(im, (i * w, 18)); d.text((i * w + 4, 3), f"{t:g}s", fill="black")
sheet.save(out)
