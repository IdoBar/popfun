# PopFun v1.0.2 (Zenodo release description draft)

PopFun (Population Fungal Variant Calling) is a Nextflow DSL2 pipeline for population-scale fungal variant discovery from whole-genome sequencing (WGS) data. It supports read QC, alignment, duplicate marking, variant calling, strict filtering, optional replicate-based error estimation, optional population genetics analyses, and integrated MultiQC reporting.

This record corresponds to release v1.0.2.

## Highlights in v1.0.2

- Added support for saving generated BAM and BAI outputs.
- Added support for BAM inputs when starting the workflow at the `call` stage.
- Moved bundled test datasets and reference assets out of the GitHub repository and into Zenodo.
- Updated the results directory structure.
- Preserved filtered VCF outputs for each caller.
- Changed the default Freebayes region splitter to `coverage`, with `mosdepth` as the default backend.

## Scope and intended use

PopFun is designed for clonal fungal isolate collections and related cohort-scale analyses. The workflow is highly parameterized and supports multiple caller and aligner combinations.

## Key methods and tools

- Workflow engine: Nextflow DSL2
- Core callers: Freebayes and GATK HaplotypeCaller
- Optional ensemble matching: RTG Tools (`vcfeval`) or `bcftools`-based matching
- Coverage-balanced Freebayes sharding backend: `mosdepth` (default in v1.0.2)
- Reporting: MultiQC

## Inputs and outputs

- Inputs: FASTQ samplesheets (default), or BAM inputs when starting at `--start_at call`.
- Outputs: caller-specific and filtered VCFs, optional saved BAM/BAI outputs, optional error-estimation outputs, optional population-genetics outputs, and MultiQC summary reports.

## Reproducibility and provenance

- Source code and release tags: [GitHub repository](https://github.com/IdoBar/popfun)
- Release notes: [v1.0.2 release notes](https://github.com/IdoBar/popfun/releases/tag/v1.0.2)
- Changelog: [CHANGELOG.md](https://github.com/IdoBar/popfun/blob/main/CHANGELOG.md)

## Suggested citation

If you use PopFun in your work, please cite the workflow and relevant software listed in:

- [CITATIONS.md](https://github.com/IdoBar/popfun/blob/main/CITATIONS.md)

Zenodo DOI for this archived release: [10.5281/zenodo.20345437](https://doi.org/10.5281/zenodo.20345437)

Suggested software citation:

> Bar, I. (2026). PopFun: Population-Scale Fungal Variant Calling Pipeline [Computer software]. Zenodo. [https://doi.org/10.5281/zenodo.20345437](https://doi.org/10.5281/zenodo.20345437)
