# ============================================================
# PopFun BAI splitter container
# Lightweight NumPy/SciPy runtime for vendored Freebayes helper
# ============================================================

FROM python:3.11-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

LABEL org.opencontainers.image.source="https://github.com/IdoBar/popfun" \
    org.opencontainers.image.title="popfun-bai-splitter" \
    org.opencontainers.image.description="PopFun FREEBAYES_SPLIT_REGIONS_BAI runtime with bash, NumPy, and SciPy" \
    org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        coreutils \
        findutils \
        gawk \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        numpy==1.23.5 \
        scipy==1.10.1

RUN python3 --version \
    && python3 -c "import numpy, scipy; print('python-stack-ok')" \
    && command -v bash \
    && command -v awk \
    && command -v sort \
    && command -v find \
    && command -v cut \
    && command -v wc
