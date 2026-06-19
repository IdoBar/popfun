# Changelog

## v1.0.4 - 2026-06-19

- Added experimental k-mer analysis branch (`--kmer_analysis`): per-sample sourmash sketching/comparison and KAT hist/GCP analyses, with results included in MultiQC.
- Added `--kmer` parameter to set k-mer size for both sourmash and KAT (default: 31).
- Fixed KAT exit-134 post-output abort by gracefully handling late matplotlib crashes.
- Added sourmash sample-level signature naming to produce clean labels in MultiQC compare heatmap.
- MultiQC now always runs as the final step regardless of `--stop_at` value.
- Removed `multiqc` as a valid `--stop_at` option; added `popgen` as the new terminal stage.
- Changed default `--stop_at` from `multiqc` to `filter`.
- Fixed duplicate sample rows in MultiQC summary table caused by MarkDuplicates `.metrics` filename suffix.
- Added sourmash native module to MultiQC report ordering.

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
