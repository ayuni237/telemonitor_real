# Research image: risk service (FastAPI), server worker, tests and analysis scripts,
# with the exact library versions that produced the thesis numbers (requirements-lock.txt).
# docker-compose.yml (C:\Projects) mounts the code, configs and artifacts at run time, so
# edits need a restart, not a rebuild; rebuild only when requirements-lock.txt changes.
FROM python:3.10.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TELEMONITOR_ARTIFACTS=/work/artifacts

# libgomp: OpenMP runtime used by CatBoost and PyTorch
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgomp1 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY requirements-lock.txt .
# +cpu exists only on the PyTorch index; torch's own dependencies come from PyPI
RUN pip install torch==2.12.0+cpu --extra-index-url https://download.pytorch.org/whl/cpu \
 && pip install -r requirements-lock.txt

COPY pyproject.toml ./
COPY src ./src
COPY configs ./configs
RUN pip install --no-deps -e .

# no data, outputs, artifacts or keys in the image (.dockerignore): they are mounted
EXPOSE 8000
CMD ["uvicorn", "telemonitor.serve.app:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8000"]
