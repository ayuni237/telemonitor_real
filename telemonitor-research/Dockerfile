# Research image: tests, analysis scripts, benchmark, local risk service (FastAPI).
# The project folder is mounted at /work at run time (docker-compose.yml), so code,
# data and outputs stay on the host; the image only holds Python and the libraries.
FROM python:3.10.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# libgomp: OpenMP runtime used by CatBoost, XGBoost and PyTorch
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgomp1 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY requirements-docker.txt .
RUN pip install torch==2.12.0 --index-url https://download.pytorch.org/whl/cpu \
 && pip install -r requirements-docker.txt

# editable install: /work/src is the mounted source, so edits need no rebuild
COPY pyproject.toml ./
COPY src ./src
RUN pip install --no-deps -e .

CMD ["python", "-m", "pytest", "-q"]
