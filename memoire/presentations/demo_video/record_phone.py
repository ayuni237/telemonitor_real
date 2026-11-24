"""Phone takes of the film, driven through adb (tap by label from the accessibility tree,
type like a person, screenrecord). See FILM_SCRIPT.md for what each take shows.

    python record_phone.py show                # labels on screen now
    python record_phone.py prep                # demo status bar, screen on, do-not-disturb off
    python record_phone.py p1|p2|p3|p4|p5|p6   # one take -> rec/<take>.mp4 (+ .json with step times)
    python record_phone.py restore             # status bar, screen timeout and touches back to normal

The phone must be unlocked, on USB, with `adb reverse tcp:8000 tcp:8000` (risk service).
When adb lists it twice (USB and wifi), set ANDROID_SERIAL to the USB serial first.
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
ADB = ["adb"]                     # adb itself reads ANDROID_SERIAL
SIGNUP_EMAIL = "esther.signup@example.com"


def sh(*args: str, check: bool = True) -> str:
    p = subprocess.run([*ADB, "shell", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and p.returncode:
        raise RuntimeError(p.stderr)
    return p.stdout


def nodes():
    sh("uiautomator", "dump", "/sdcard/ui.xml", check=False)
    x = sh("cat", "/sdcard/ui.xml")
    out = []
    for m in re.finditer(r"<node ([^>]*)>", x):
        a = m.group(1)

        def attr(name: str) -> str:
            f = re.search(name + r'="([^"]*)"', a)
            return f.group(1) if f else ""

        nums = re.findall(r"\d+", attr("bounds"))
        if len(nums) == 4:
            out.append((attr("text") or attr("content-desc") or attr("hint"), tuple(map(int, nums)), attr("class")))
    return out


def find(text: str, nth: int = 0, exact: bool = False, tries: int = 6):
    for _ in range(tries):
        hits = [n for n in nodes() if (n[0] == text if exact else text.lower() in n[0].lower())]
        if len(hits) > nth:
            return hits[nth]
        time.sleep(0.7)
    raise LookupError(f"not on screen: {text!r} (#{nth})")


def tap_xy(x: int, y: int, pause: float = 0.6) -> None:
    sh("input", "tap", str(x), str(y))
    time.sleep(pause)


def tap(text: str, nth: int = 0, exact: bool = False, pause: float = 0.7, dy: int = 0) -> None:
    _, (l, t, r, b), _ = find(text, nth, exact)
    tap_xy((l + r) // 2, (t + b) // 2 + dy, pause)


def type_text(s: str, gap: float = 0.12) -> None:
    for ch in s:                                   # quoted: the device shell must not read & ( ) ; $ |
        arg = "%s" if ch == " " else ("\"'\"" if ch == "'" else f"'{ch}'")
        sh("input", "text", arg)
        time.sleep(gap)


def clear_field(xy) -> None:
    tap_xy(*xy, 0.3)
    sh("input", "keyevent", "KEYCODE_MOVE_END")
    sh("input", "keyevent", *(["67"] * 45))


def key(code: str, pause: float = 0.5) -> None:
    sh("input", "keyevent", code)
    time.sleep(pause)


def swipe(y0: int, y1: int, ms: int = 600, pause: float = 0.8) -> None:
    sh("input", "swipe", "540", str(y0), "540", str(y1), str(ms))
    time.sleep(pause)


def hide_keyboard() -> None:
    if "mInputShown=true" in sh("dumpsys", "input_method", check=False):
        key("4")                                   # Back closes the keyboard only


def show() -> None:
    for label, b, cls in nodes():
        if label:
            print(b, cls.split(".")[-1], label[:80].replace("\n", " | ").encode("ascii", "replace").decode())


def demo(cmd: str, **extra: str) -> None:
    args = ["am", "broadcast", "-a", "com.android.systemui.demo", "-e", "command", cmd]
    for k, v in extra.items():
        args += ["-e", k, v]
    sh(*args, check=False)


def prep() -> None:
    sh("settings", "put", "global", "sysui_demo_allowed", "1")
    demo("enter")
    demo("clock", hhmm=time.strftime("%H%M"))
    demo("battery", level="100", plugged="false")
    demo("network", wifi="show", level="4")
    demo("network", mobile="show", datatype="4g", level="4")
    demo("notifications", visible="false")
    sh("svc", "power", "stayon", "usb", check=False)
    sh("settings", "put", "system", "show_touches", "1", check=False)
    sh("cmd", "notification", "set_dnd", "off", check=False)
    key("KEYCODE_WAKEUP")
    print("demo status bar on, screen kept on, touches shown, do-not-disturb off")


def restore() -> None:
    demo("exit")
    sh("svc", "power", "stayon", "false", check=False)
    sh("settings", "put", "system", "show_touches", "0", check=False)
    sh("cmd", "connectivity", "airplane-mode", "disable", check=False)
    print("phone settings restored")


class Take:
    """adb screenrecord in the background; marks the time of each step."""

    def __init__(self, name: str):
        self.name, self.marks = name, {}

    def __enter__(self):
        key("KEYCODE_WAKEUP", 0.3)
        self.proc = subprocess.Popen([*ADB, "shell", "screenrecord", "--bit-rate", "16000000", "--time-limit", "180",
                                      f"/sdcard/{self.name}.mp4"])
        self.t0 = time.time()
        time.sleep(1.2)
        self.mark("start")
        return self

    def mark(self, what: str) -> None:
        self.marks[what] = round(time.time() - self.t0, 2)
        print(f"{self.marks[what]:7.2f}  {what}", flush=True)

    def __exit__(self, *exc):
        time.sleep(1.0)
        sh("pkill", "-2", "screenrecord", check=False)
        self.proc.wait(timeout=20)
        time.sleep(1.5)
        out = HERE / "rec" / f"{self.name}.mp4"
        subprocess.run([*ADB, "pull", f"/sdcard/{self.name}.mp4", str(out)], check=True,
                       capture_output=True)
        self.marks["wallclock_start"] = self.t0
        out.with_suffix(".json").write_text(json.dumps(self.marks, indent=1), encoding="utf-8")
        print(out, "saved")


def p1() -> None:
    """Sign-up with the clinician code (throwaway account with Esther's name)."""
    with Take("p1") as k:
        time.sleep(1.5)
        tap("Français", pause=1.8)
        k.mark("french")
        tap("English", pause=1.3)
        k.mark("create")
        tap("Create an account", pause=1.5)
        tap("Jean Mbarga")
        type_text("Esther Mbella")
        tap("you@example.com")
        type_text(SIGNUP_EMAIL, 0.06)
        tap("At least 6 characters")
        type_text("Demo-2026-signup", 0.05)
        hide_keyboard()
        k.mark("code")
        tap("MBARGA")
        type_text("DLA7K2", 0.25)
        hide_keyboard()
        time.sleep(2.5)
        k.mark("linked")
        swipe(1500, 900)
        tap("I have read and I accept")
        k.mark("terms")
        time.sleep(1.0)
        btn = [n for n in nodes() if n[0] == "Create account" and n[2].endswith("Button")]
        tap_xy(*centre(btn[0][1]), 6.0)
        k.mark("created")
        time.sleep(2.5)


def fill(hint: str, text: str, gap: float = 0.2) -> None:
    """Types into the first empty field showing `hint` (filled fields show their value instead)."""
    for i in range(6):
        eds = [n for n in nodes() if n[2].endswith("EditText") and n[0] == hint]
        if eds:
            tap_xy(*centre(eds[0][1]), 0.4)
            type_text(text, gap)
            return
        if i == 0:
            hide_keyboard()                        # the keyboard hides the lower fields
        else:
            swipe(1300, 800, 450, 0.6)
    raise LookupError(hint)


def p2() -> None:
    """Log a reading: two BP readings, glucose before a meal, pulse by camera (finger on the camera)."""
    with Take("p2") as k:
        time.sleep(2.0)
        tap("Log a reading", pause=1.8)
        k.mark("form")
        fill("Systolic", "186")
        fill("Diastolic", "110")
        fill("Pulse (optional)", "90")
        k.mark("reading 2")
        fill("Systolic", "182")
        fill("Diastolic", "108")
        fill("Pulse (optional)", "88")
        k.mark("glucose")
        fill("Glucose", "6.1", 0.3)
        hide_keyboard()
        swipe(1700, 1000, 700, 1.0)
        k.mark("camera")
        tap("Measure", exact=True, pause=2.5)
        print(">>> FINGER ON THE BACK CAMERA NOW <<<", flush=True)
        find("Use this value", tries=80)
        k.mark("pulse measured")
        time.sleep(1.5)
        tap("Use this value", pause=1.8)
        k.mark("context")
        tap("Choose", pause=1.2)
        tap("Before a meal", pause=1.8)
        swipe(1600, 1100, 700, 1.0)
        k.mark("graded")
        time.sleep(3.0)


def p3() -> None:
    """Offline: airplane mode, save, the red dialog."""
    sh("cmd", "connectivity", "airplane-mode", "enable", check=False)
    demo("network", airplane="show", wifi="hide", mobile="hide")
    time.sleep(2)
    with Take("p3") as k:
        time.sleep(2.0)
        swipe(1600, 900)
        k.mark("save")
        tap("Save Reading", pause=2.5)
        k.mark("dialog")
        time.sleep(3.5)
        tap("I understand", pause=2.5)
        k.mark("home offline")
        time.sleep(2.0)


def p4() -> None:
    """Back online: level, model line, trend, then History."""
    if sh("settings", "get", "global", "airplane_mode_on", check=False).strip() == "1":
        sh("cmd", "connectivity", "airplane-mode", "disable", check=False)
        demo("network", airplane="hide", wifi="show", level="4", mobile="show", datatype="4g")
        time.sleep(8)
    with Take("p4") as k:
        time.sleep(3.0)
        k.mark("scroll")
        swipe(1700, 1100, 1500, 2.0)
        swipe(1700, 1000, 1500, 2.5)
        k.mark("history")
        tap("Tab 2 of 4", pause=3.0)
        swipe(1600, 1000, 1500, 2.5)
        k.mark("profile")
        tap("Tab 4 of 4", pause=3.0)
        swipe(1700, 1000, 1800, 2.0)
        swipe(1700, 900, 1800, 2.5)
        k.mark("end")


def p5() -> None:
    """The assistant, then Find care near you (no map is opened)."""
    with Take("p5") as k:
        tap("Tab 1 of 4", pause=1.5)
        k.mark("assistant")
        robot = [n for n in nodes() if "assistant" in n[0].lower()]
        tap_xy(*centre(robot[0][1])) if robot else tap_xy(964, 2070)
        time.sleep(1.5)
        tap("Ask a health question", pause=0.8)
        type_text("Can I eat plantain if I have diabetes?", 0.08)
        bar = [n for n in nodes() if n[2].endswith("EditText")][-1][1]
        send = [n for n in nodes() if n[1][0] >= bar[2] and n[1][1] >= bar[1] - 40]
        tap_xy(*centre(send[0][1])) if send else tap_xy(993, 2279)
        k.mark("asked")
        time.sleep(9.0)
        swipe(1600, 1000, 1200, 2.5)
        k.mark("care")
        hide_keyboard()
        key("4", 1.5)
        for _ in range(8):                                   # the card sits lower on Home
            hits = [n for n in nodes() if "find care" in n[0].lower() or "find a hospital" in n[0].lower()]
            if hits:
                tap_xy(*centre(hits[0][1]), 3.5)
                break
            swipe(1600, 900, 900, 0.8)
        k.mark("end")


def p6() -> None:
    """Phone in the background while the clinician answers: notification, open, reply.
    A neutral app (Clock) is in front, so the home screen and its apps never appear."""
    sh("am", "start", "-n", "com.google.android.deskclock/com.android.deskclock.DeskClock", check=False)
    time.sleep(2.0)
    try:
        tap("Stopwatch", exact=True, pause=1.5)
    except LookupError:
        pass
    with Take("p6") as k:
        hits = []
        for _ in range(120):
            hits = [n for n in nodes() if "clinician" in n[0].lower() and n[1][1] < 1000]
            if hits:
                break
            time.sleep(0.5)
        k.mark("notification")
        time.sleep(2.5)
        tap_xy(*centre(hits[0][1]), 3.5)
        k.mark("opened")
        try:
            tap("Tab 3 of 4", pause=2.5)
        except LookupError:
            pass
        k.mark("conversation")
        bar = [n for n in nodes() if n[2].endswith("EditText")][-1][1]
        tap_xy(*centre(bar), 0.8)
        type_text("Thank you doctor, I will come tomorrow morning.", 0.06)
        bar = [n for n in nodes() if n[2].endswith("EditText")][-1][1]
        send = [n for n in nodes() if n[1][0] >= bar[2] - 5 and abs(centre(n[1])[1] - centre(bar)[1]) < 120]
        tap_xy(*centre(send[0][1]), 1.0) if send else key("66")
        hide_keyboard()
        k.mark("replied")
        time.sleep(4.0)


def centre(b):
    l, t, r, bt = b
    return (l + r) // 2, (t + bt) // 2


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    {"show": show, "prep": prep, "restore": restore, "p1": p1, "p2": p2, "p3": p3, "p4": p4, "p5": p5, "p6": p6}[cmd]()
