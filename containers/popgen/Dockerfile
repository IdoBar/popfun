# ============================================================
# PopFun POPGEN container
# Includes Python runtime + IQ-TREE + MrBayes
# ============================================================

FROM python:3.9-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

LABEL org.opencontainers.image.source="https://github.com/IdoBar/popfun" \
    org.opencontainers.image.title="popfun-popgen" \
    org.opencontainers.image.description="PopFun POPGEN_ANALYSES runtime with IQ-TREE and MrBayes" \
    org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        iqtree \
        mrbayes \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        numpy==1.23.5 \
        pysam==0.19.1

# Sanity checks
RUN python --version \
    && python -c "import numpy, pysam; print('python-stack-ok')" \
    && (command -v iqtree2 || command -v iqtree) \
    && command -v mb \
    && command -v ps
