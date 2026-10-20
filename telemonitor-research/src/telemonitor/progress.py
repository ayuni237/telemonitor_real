"""Progress bars for the long steps (tqdm).

Set TELEMONITOR_PROGRESS=0 to disable them (tests, continuous integration).
When the output is a log file rather than a terminal, bars refresh every 30 s
so that the log stays readable.
"""
from __future__ import annotations

import os
import sys

from tqdm import tqdm


def enabled() -> bool:
    return os.environ.get("TELEMONITOR_PROGRESS", "1") != "0"


def progress(iterable=None, *, desc: str, total: int | None = None, leave: bool = True, unit: str = "it"):
    interactive = sys.stderr.isatty()
    return tqdm(iterable, desc=desc, total=total, leave=leave, unit=unit, disable=not enabled(),
                mininterval=0.5 if interactive else 30.0, dynamic_ncols=True, file=sys.stderr)
