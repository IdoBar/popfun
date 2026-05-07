# ============================================================
# PopFun POPGEN container
# Includes Python scientific stack + IQ-TREE + MrBayes
# ============================================================

FROM mambaorg/micromamba:1.5.10

ARG MAMBA_DOCKERFILE_ACTIVATE=1
ENV PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        procps \
    && rm -rf /var/lib/apt/lists/*
USER mambauser

LABEL org.opencontainers.image.source="https://github.com/IdoBar/popfun" \
    org.opencontainers.image.title="popfun-popgen" \
    org.opencontainers.image.description="PopFun POPGEN_ANALYSES runtime with IQ-TREE and MrBayes" \
      org.opencontainers.image.licenses="MIT"

RUN micromamba install -y -n base -c conda-forge -c bioconda \
        python=3.9 \
        numpy=1.23.5 \
        pandas=1.4.2 \
        pysam=0.19.1 \
        iqtree=2.4.0 \
        mrbayes=3.2.7 \
    && micromamba clean --all --yes

# Sanity checks
RUN python --version \
    && python -c "import numpy, pandas, pysam; print('python-stack-ok')" \
    && (command -v iqtree2 || command -v iqtree) \
    && command -v mb \
    && command -v ps
