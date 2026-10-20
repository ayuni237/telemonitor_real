import os

# progress bars off during tests (they are exercised by the scripts)
os.environ.setdefault("TELEMONITOR_PROGRESS", "0")
