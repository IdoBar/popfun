# Changelog

## v1.0.2 - 2026-05-23

- Updated MultiQC from 1.33 to 1.35 across process container, conda pin, and software versions reporting tables.
- Published a Zenodo archival DOI for PopFun: `10.5281/zenodo.20345437`.

## v1.0.1 - 2026-05-22

- Added support for saving generated BAM and BAI outputs.
- Added support for BAM inputs when starting the workflow at the `call` stage.
- Moved bundled test datasets and reference assets out of the GitHub repository and into Zenodo.
- Updated the results directory structure.
- Preserved filtered VCF outputs for each caller.
- Changed the default Freebayes region splitter to `coverage`, with `mosdepth` as the default backend.
