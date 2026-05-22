# PopFun: Population-Scale Fungal Variant Calling Pipeline

<p align="center">
    <img src="assets/popfun.png" alt="PopFun logo" width="420" />
</p>

<!-- 
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](https://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/) -->
[![Repo](https://img.shields.io/badge/GitHub-IdoBar%2Fpopfun-181717?logo=github)](https://github.com/IdoBar/popfun)
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg?labelColor=000000&logo=data:image/svg%2bxml;base64,PHN2ZyB3aWR0aD0iMjUxIiBoZWlnaHQ9IjI1MiIgdmlld0JveD0iMCAwIDI1MSAyNTIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+DQo8cGF0aCBkPSJNMCA0Ny42MzQ1QzM5LjQ1IDUwLjI1NDMgNzEuMDYgODEuOTQyMiA3My41NCAxMjEuNDNIMTE5LjYxQzExNy4wNSA1Ni40NzM5IDY0LjkzIDQuMjU3NDQgMCAxLjU1NzYyVjQ3LjYzNDVaIiBmaWxsPSIjMjJBRTYzIi8+DQo8cGF0aCBkPSJNNzMuOCAxMzEuOTM5QzcxLjE4IDE3MS4zODYgMzkuNDkgMjAyLjk5NCAwIDIwNS40NzRWMjUxLjU0MUM2NC45NiAyNDguOTgxIDExNy4xOCAxOTYuODY1IDExOS44OCAxMzEuOTM5SDczLjhaIiBmaWxsPSIjMjJBRTYzIi8+DQo8cGF0aCBkPSJNMTc2LjIwMSAxMjEuMTZDMTc4LjgyMSA4MS43MTIyIDIxMC41MTEgNTAuMTA0MyAyNTAuMDAxIDQ3LjYyNDVWMS41NTc2MkMxODUuMDQxIDQuMTE3NDQgMTMyLjgyMSA1Ni4yMzM5IDEzMC4xMjEgMTIxLjE2SDE3Ni4yMDFaIiBmaWxsPSIjMjJBRTYzIi8+DQo8cGF0aCBkPSJNMjUwLjAwMSAyMDUuNDY0QzIxMC41NTEgMjAyLjg0NSAxNzguOTQxIDE3MS4xNTcgMTc2LjQ2MSAxMzEuNjY5SDEzMC4zOTFDMTMyLjk1MSAxOTYuNjI1IDE4NS4wNzEgMjQ4Ljg0MiAyNTAuMDAxIDI1MS41NDFWMjA1LjQ2NFoiIGZpbGw9IiMyMkFFNjMiLz4NCjwvc3ZnPg==)](https://www.nextflow.io/)
[![run with conda](https://img.shields.io/badge/run%20with-conda-3EB049.svg?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed.svg?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity/apptainer](https://img.shields.io/badge/run%20with-singularity%2Fapptainer-F48B11.svg?labelColor=000000&logo=data:image/svg%2bxml;base64,PHN2ZyB3aWR0aD0iMjQ1IiBoZWlnaHQ9IjI0MCIgdmlld0JveD0iNjAgMCAzMTAgMjUwIiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgk8cGF0aCBkPSJtIDI3MC4xOCwyNTMuOTggYyAtMS44LC0xLjIgLTMuNCwtMyAtNC40LC01LjIgbCAtNTIuNiwtMTE3LjQgYyAtMi4yLC00LjggLTMuOCwtOC42IC01LjIsLTExLjYgLTIuMiwtNC40IC0yLjIsLTUuNiAtMi4yLC02LjQgMCwtMi4yIDAuOCwtMy44IDIuNiwtNC44IHYgLTQuNCBoIC00My4yIHYgNC40IGMgMC44LDAuNCAxLjIsMS4yIDEuOCwxLjggMC40LDAuOCAwLjgsMS44IDAuOCwzIDAsMS4yIC0wLjQsMyAtMS44LDUuNiAtMS4yLDIuNiAtMi42LDUuNiAtNC40LDkuNCBsIC01MS44LDExNyBjIC0wLjgsMS44IC0yLjIsNC40IC0zLjgsNy40IC0xLjgsMyAtNC44LDQuNCAtOC4yLDQuOCB2IDMuOCBoIDQ5LjYgdiAtMy44IGMgLTUuNiwwIC04LjIsLTIuMiAtOC4yLC01LjYgMCwtMS44IDAuOCwtNC44IDMsLTkgMS44LC0zLjQgMy44LC03LjggNS42LC0xMiAyNC42LDkuNCA1Mi4yLDEwIDc2LjgsMC44IDIuMiw0LjQgMy44LDguMiA1LjIsMTEuMiAxLjgsMy40IDIuNiw2LjQgMi42LDguNiAwLDIuMiAtMC44LDMuOCAtMi4yLDQuOCAtMS4yLDAuNCAtMi4yLDAuOCAtMy40LDEuMiB2IDMuOCBoIDUwLjQgdiAtMy44IGMgLTIuOCwtMS44IC01LjQsLTIuOCAtNywtMy42IHogbSAtMTExLjQsLTQ3IDI3LjYsLTYxLjQgMjgsNjIuMiBjIC0xOCw2IC0zNy40LDYgLTU1LjYsLTAuOCB6IiBmaWxsPSJ3aGl0ZSIvPiA8cGF0aCBkPSJtIDg5Ljc4LDE0MC45OCBjIDAsLTkgMS4yLC0xNy42IDMuNCwtMjYuNCBsIC0yOCwtMTIuNiBjIC0zLjgsMTIgLTYsMjQuNiAtNiwzNy42IDAsMzUgMTQuMiw2OC42IDM5LjgsOTIuOCBsIDEuOCwtMy40IDExLjIsLTI1LjQgYyAtMTMuNiwtMTcuNCAtMjIuMiwtMzkgLTIyLjIsLTYyLjYgeiIgZmlsbD0iIzkzOTU5OCIvPiA8cGF0aCBkPSJtIDMxMC4xOCwxMDIuNTggLTI4LDEyLjYgYyAyLjIsOC4yIDMuNCwxNi44IDMuNCwyNS44IDAsMjMuOCAtOC42LDQ1LjggLTIyLjgsNjIuNiBsIDExLjYsMjUuNCAxLjgsMy40IGMgMjUuNCwtMjQuMiAzOS44LC01Ny44IDM5LjgsLTkyLjggLTAuMiwtMTIuNCAtMi4yLC0yNSAtNS44LC0zNyB6IiBmaWxsPSIjRjc5NDIxIi8+IDxwYXRoIGQ9Im0gNzEuMTgsODYuOTggMjcuNiwxMi42IGMgMTQuNiwtMzEgNDQuOCwtNTMgODAuMiwtNTYuMiB2IC0zMC42IGMgLTQ2LDIuNiAtODguNCwzMS40IC0xMDcuOCw3NC4yIHoiIGZpbGw9IiMxRTk1RDMiLz4gPHBhdGggZD0ibSAzMDQuMTgsODYuOTggYyAtMTkuNCwtNDIuOCAtNjEuOCwtNzEuNiAtMTA4LjQsLTc0LjYgdiAzMC42IGMgMzUuOCwzIDY2LDI1IDgwLjYsNTYuMiB6IiBmaWxsPSIjNkZCNTQ0Ii8+PC9zdmc+)](https://sylabs.io/docs/)
[![Changelog](https://img.shields.io/badge/changelog-CHANGELOG-2f6f99.svg?labelColor=000000)](CHANGELOG.md)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20345437.svg)](https://doi.org/10.5281/zenodo.20345437)

## Introduction

**PopFun** (Population Fungal Variant Calling) is a highly scalable bioinformatics pipeline for identifying single nucleotide polymorphisms (SNPs) and insertions/deletions (Indels) from whole-genome sequencing (WGS) data of clonal fungal isolate collections and related population-scale cohorts.

Built using Nextflow DSL2 and strictly adhering to nf-core data structures (including meta maps), PopFun bridges the gap between raw sequencing reads and high-quality, filtered variant calls. It is highly parameterized, automatically handles missing reference indices, and includes a parallel track for estimating error rates across replicate libraries of the same samples.

## Requirements

PopFun requires Nextflow plus one supported execution backend.

- Nextflow: minimum supported `22.10.1`; recommended `23.04.4` or newer stable release
- Java (for Nextflow runtime): recommended `OpenJDK 17`; minimum `Java 11`
- Note: If remote URL staging fails with TLS/PSK warnings, upgrade to Java 17
- One execution backend: Docker (recommended), Conda/Mamba, or Singularity/Apptainer
- System tools: `bash`
- Network access: required to pull remote containers and reference/input files (when URLs are used)

## Pipeline Summary

By default, **PopFun** performs the following steps:

1. **Reference Preparation**: Automatically decompresses the reference (if provided as `.fasta.gz`) and generates missing `.fai`, `.dict`, and aligner index directories (`bwa-mem2` or `bowtie2`) if not provided by the user.
2. **Read QC & Trimming**: `fastp` (default) OR `Trimmomatic` (with `FastQC`).
3. **Read Alignment**: `bwa-mem2` (default) or `bowtie2`.
4. **BAM Processing**:
    * Merges multiple libraries belonging to the same sample (`samtools`).
    * Marks optical/PCR duplicates (`bamsormadup` by default, with optional `GATK MarkDuplicates`, `sambamba`, or `FastDup`).
5. **Alignment QC**: `Qualimap` (Supports optional `.gff`/`.bed` annotations for targeted region metrics).
6. **Variant Calling**: `Freebayes` (Population mode default), `GATK HaplotypeCaller`, or an `ensemble` intersection of both callers.
    * Supports Freebayes population-level calling, or individual sample calling + merging.
    * Population mode can split chromosomes into multiple sub-regions for finer internal Freebayes region fan-out using either fixed-size FASTA chunks or BAI data-aware regioning.
    * After global region generation, per-chromosome region files are produced so each population shard remains chromosome-scoped for concatenation.
    * `--caller ensemble` runs both GATK and Freebayes population calling, filters each caller VCF first, then combines only shared REF/ALT calls after reference-aware normalization (`bcftools norm -f`). At each shared site, it retains the higher-QUAL representation and reports raw caller VCFs in the results directory.
    * `--save_bams` controls which BAM files are published to `results/aligned`: `none` (default) publishes no BAMs, `merged` publishes only merged BAMs under `results/aligned/merged`, and `all` publishes both individual aligned BAM/BAI pairs under `results/aligned/ind` and merged BAMs under `results/aligned/merged`.
7. **Error Estimation (Optional)**: If `--error_estimate true` is flagged, the pipeline automatically separates replicate libraries, calls variants on them independently, and calculates genotype discordance rates using a custom Python module. The raw per-library VCFs used in this comparison are also retained in `results/variants/error_estimate_libraries/`.
8. **Population Genetics (Optional)**: If `--popgen true`, PopFun performs PCA (PC1-PC3) and constructs a phylogenetic tree from the final cohort VCF (regardless of variant caller and calling mode), then adds both panels to MultiQC. If a `pop` column is present in the samplesheet, it is used to color PCA markers and tree nodes.
9. **Variant Filtering**: Strictly filters VCFs based on Depth (DP), Quality (QUAL), and polymorphism, while recalculating INFO tags (`bcftools +fill-tags`). Outputs distinct `.snps.vcf` and `.indels.vcf` files.
10. **Final Reporting**: Aggregates QC metrics and software versions across all steps into a single HTML report (`MultiQC`).

## Quick Start

1. Install [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html#installation) (>=22.10.1).
2. Install [Conda](https://docs.conda.io/en/latest/), [Docker](https://docs.docker.com/engine/installation/), or [Singularity/Apptainer](https://sylabs.io/guides/3.0/user-guide/).
    * Note: Apptainer is only supported from Nextflow version 22.11.0-edge and later.
3. Create a `samplesheet.csv` with your input data.
     * Note: Rows with the exact same `sample` ID but different `library` IDs will be automatically merged post-alignment.
     * Optional: Populate the `pop` column with population/group labels. This is used by the population genetics module to color PCA markers and phylogenetic tree nodes.
     * Optional: Populate the `bam` column when running with `--start_at call`. Each row must provide a BAM path in that mode. Rows sharing the same `sample` ID will still be merged before duplicate marking, so both per-library and per-sample BAM inputs are accepted. If a sidecar index (`.bam.bai` or `.bai`) is missing next to an input BAM, PopFun will generate one automatically before merging.

    ```csv
        sample,library,fq1,fq2,pop,bam
        FungusA,Lib1,data/A_L1_1.fq.gz,data/A_L1_2.fq.gz,Pop_1,
        FungusA,Lib2,data/A_L2_1.fq.gz,data/A_L2_2.fq.gz,Pop_1,
        FungusB,Lib1,data/B_L1_1.fq.gz,data/B_L1_2.fq.gz,Pop_2,
    ```

    For `--start_at call`, provide BAMs instead of FASTQs:

    ```csv
        sample,library,fq1,fq2,pop,bam
        FungusA,Lib1,,,Pop_1,data/A_L1.sorted.bam
        FungusA,Lib2,,,Pop_1,data/A_L2.sorted.bam
        FungusB,Lib1,,,Pop_2,data/B_merged.sorted.bam
    ```

4. Run the pipeline:

    ```bash
        nextflow run main.nf \
            -profile conda \
            --input samplesheet.csv \
            --ref data/reference.fa \
            --outdir results
    ```

    *Swap `-profile conda` with `-profile docker` or `-profile singularity` or `-profile apptainer` depending on your environment.*

## Advanced Usage

PopFun allows you to bypass expensive indexing steps by providing pre-built directories, and allows fine-grained control over tool arguments.

**Example: Providing pre-built indices, annotations, and custom trimming arguments:**

```bash
    nextflow run main.nf \
        -profile docker \
        --input samplesheet.csv \
        --ref data/reference.fa \
        --bwa_index path/to/bwa_index/ \
        --annotation data/genes.gff \
        --trimmer trimmomatic \
        --trimmomatic_args "ILLUMINACLIP:TruSeq3-PE.fa:2:30:10 LEADING:5 TRAILING:5 MINLEN:50" \
        --error_estimate true
```

### Key Parameters

**Inputs & References:**

* `--ref`: Path to reference FASTA.
* `--annotation`: (Optional) Path to `.gff`, `.gff3`, or `.bed` for targeted Qualimap QC.
* `--bwa_index`: (Optional) Path to pre-built BWA-mem2 index directory.
* `--bowtie2_index`: (Optional) Path to pre-built Bowtie2 index directory.

**Tool Selection & Logic:**

* `--trimmer`: `fastp` (default) or `trimmomatic`
* `--aligner`: `bwa-mem2` (default) or `bowtie2`
* `--caller`: `freebayes` (default), `gatk`, or `ensemble`
* `--error_estimate_caller`: Caller used for the optional per-library error-estimation branch: `freebayes` or `gatk`. By default this follows `--caller`, except `--caller ensemble` defaults to `freebayes` for error estimation.
* `--markdup_tool`: `bamsormadup` (default), `gatk`, `sambamba`, or `fastdup`
* `--start_at`: `qc` (default), `alignment`, or `call`. With `--start_at call`, the samplesheet must include a `bam` column and duplicate marking still runs before variant calling. Input BAMs are auto-indexed when a matching sidecar index is not present.
* `--stop_at`: Final pipeline stage to execute: `qc`, `alignment`, `call`, `filter`, or `multiqc` (default). Use this to stop after an intermediate stage without running the remaining downstream steps.
* `--freebayes_mode`: `population` (default) or `individual`
* `--freebayes_region_splitter`: Region splitting strategy for Freebayes fan-out: `coverage` (default, coverage-balanced chunks derived from alignment depth) or `fai` (fixed-size chunks from the FASTA index).
* `--freebayes_chunk_size`: Chunk size passed to `fasta_generate_regions.py` for splitting genomic regions in Freebayes population-mode. (Default: `100000`).
* `--freebayes_coverage_tool`: Coverage tool used when `--freebayes_region_splitter coverage` is selected: `mosdepth` (default) or `sambamba`.
* `--freebayes_coverage_regions`: Target number of coverage-balanced regions to generate when `--freebayes_region_splitter coverage` is used. (Default: `500`).
* `--freebayes_max_chunks`: Maximum number of generated Freebayes target regions allowed in the largest per-chromosome region file before the workflow aborts and asks for coarser chunking. (Default: `2000`).
* `--freebayes_debug`: Save Freebayes per-region TSV timing diagnostics when `true`. (Default: `false`).
* `--ensemble_matcher`: Matching engine used when `--caller ensemble`: `bcftools` (default) or `rtg`.
* `--caller ensemble` currently uses strict intersection of filtered, reference-normalized (`bcftools norm -f`) GATK and Freebayes population calls, keeping the higher-QUAL record at each shared site. With `--ensemble_matcher rtg`, matching is derived from `rtg vcfeval` true-positive outputs before the same higher-QUAL selection step.
* `--error_estimate`: `false` (default) or `true`
* `--popgen`: Run population genetics module (PCA + phylogenetic tree) from final cohort VCF and add to MultiQC (Default: `false`).
* `--popgen_tree_method`: Tree construction method for population genetics (`upgma`, `nj`, `ml`, or `bayesian`, Default: `upgma`).
* `--popgen_legend_order`: Population legend order for PCA/tree (`samplesheet` or `alphabetical`, Default: `samplesheet`).

**Tool Arguments & Parameters:**

* `--ploidy`: Expected sample ploidy used by variant callers (Default: `2`, required for masking heterozygote genotypes, see `--mask_hetero` flag below). Set to `1` for true haploid genomes, or higher values for polyploid organisms.
* `--fastp_args`: Additional arguments passed to Fastp (Default: empty).
* `--trimmomatic_args`: Additional arguments passed to Trimmomatic (Default: `ILLUMINACLIP:TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36`).
* `--bwa_args`: Additional arguments passed to BWA-mem2 (Default: empty).
* `--bowtie2_args`: Additional arguments passed to Bowtie2 (Default: empty).
* `--gatk_args`: Additional arguments passed to GATK HaplotypeCaller (Default: empty).
* `--freebayes_args`: Additional arguments passed to Freebayes (Default: `--genotype-qualities --use-best-n-alleles 4`). Keep `--genotype-qualities` enabled so `GQ` fields are emitted for downstream genotype-based filtering. The default `--use-best-n-alleles 4` acts as a conservative runtime guard in low-complexity or ultra-high-coverage regions. In population mode, these arguments are forwarded to each chromosome-level Freebayes region fan-out task. Additional upstream tuning options are documented in the [Freebayes performance tuning guide](https://github.com/freebayes/freebayes?tab=readme-ov-file#performance-tuning).
* Caller parallelism inside `FREEBAYES`, `FREEBAYES_POPULATION`, `FREEBAYES_CALL_LIB`, and `GATK_HAPLOTYPECALLER` now uses the full `task.cpus` allocation for each process.

**Variant Calling Notes:**

* `--freebayes_region_splitter coverage` vendors the upstream Freebayes `coverage_to_regions.py` helper in `bin/`. The default `mosdepth` backend uses `quay.io/biocontainers/mosdepth:0.3.14--h05c3d44_0` with a small adapter that converts mosdepth interval output into the coverage stream expected by the vendored Freebayes helper. The `sambamba` backend uses `quay.io/biocontainers/sambamba:1.0.1--h6f6fda4_1` to generate coverage directly.
* Chunk-size tuning depends on how regions are generated. With `--freebayes_region_splitter coverage`, lower `--freebayes_coverage_regions` values produce coarser fan-out and higher values produce finer fan-out. With `--freebayes_region_splitter fai`, appropriate `--freebayes_chunk_size` values depend more on genome size and continuity; highly fragmented assemblies with thousands of contigs often work better with `coverage` splitting than with `fai` splitting.
* If Freebayes region generation exceeds `--freebayes_max_chunks` (default: 2000) in the largest per-chromosome region file, PopFun aborts before fan-out and asks you to lower `--freebayes_coverage_regions` or increase `--freebayes_chunk_size`, depending on the selected splitter.
* When `--freebayes_debug true` is enabled, each Freebayes task writes `.freebayes_diagnostics` debug files containing a `region_runtime.tsv` timing table and a `slowest_regions.tsv` summary of the longest-running regions. These tables include an absolute chunk `vcf_path` for each chunk. These files are skipped by default.
* `--caller ensemble` currently requires `--freebayes_mode population`. When `--error_estimate true` is also enabled, the error-estimation branch defaults to `--error_estimate_caller freebayes`; override this with `--error_estimate_caller gatk` if you want GATK-based per-library error estimation instead.

**VCF Filtering:**

Note: Genotype-based filtering relies on valid `GQ` fields. By default, PopFun enables Freebayes `--genotype-qualities` (via `--freebayes_args`) so genotype qualities are emitted and filtering behaves as expected.

* `--filter_qual`: Minimum QUAL score (Default: `30`)
* `--filter_min_dp`: Minimum Depth (Default: `10`)
* `--filter_ind_dp`: Minimum individual genotype depth (Default: `7`)
* `--mask_hetero`: Mask heterozygous genotypes (`GT=='het'`) during filtering (Default: `true`). Requires diploid variant calling (`--ploidy 2`).

## Output Directory Structure

Upon completion, the `--outdir` will contain the following structured directories:

```text
    results/
    ├── aligned/              # Optional BAM outputs when `--save_bams` is enabled
    │   ├── ind/              # Individual aligned BAM/BAI pairs when `--save_bams all`
    │   └── merged/           # Merged BAMs when `--save_bams merged` or `all`
    ├── error_estimates/      # CSV reports of replicate discordance rates
    ├── multiqc/              # Aggregated HTML QC report
    ├── population_genetics/  # PCA, phylogenetic tree, and intermediate population-genetics outputs
    ├── qc/                   # Individual QC reports (Fastp, FastQC, Qualimap, BCFtools)
    └── variants/
        ├── error_estimate_libraries/ # Raw per-library VCFs used for error-rate estimation (`--error_estimate true`)
        │   └── filtered/      # Filtered per-library VCFs for error-estimation comparisons
        ├── fb_ind/           # Raw per-sample Freebayes VCFs (if using Freebayes individual mode)
        ├── fb_merged/        # Raw merged Freebayes VCF (if using Freebayes individual mode)
        ├── fb_pop/           # Raw Freebayes population VCF (if using Freebayes population mode)
        │   └── filtered/      # Filtered Freebayes population VCF outputs
        ├── ensemble/         # Raw ensemble VCF from shared filtered GATK + Freebayes calls (after reference-aware normalization)
        │   └── filtered/      # Filtered caller inputs used to build the ensemble set
        ├── gatk_ind/         # Per-sample GATK gVCFs from HaplotypeCaller
        ├── gatk_merged/      # Cohort-combined GATK gVCFs before joint genotyping
        └── gatk_joint/       # Joint-called GATK cohort VCF (used directly in `--caller gatk` and retained in `--caller ensemble`)
            └── filtered/      # Filtered GATK joint-call outputs
```

Generated VCF filenames follow the same caller-prefix convention. Common examples include:

* `results/variants/fb_pop/fb_pop.vcf.gz`
* `results/variants/fb_merged/fb_merged.vcf.gz`
* `results/variants/gatk_joint/gatk_joint.vcf.gz`
* `results/variants/gatk_merged/gatk_merged.g.vcf.gz`
* `results/variants/fb_pop/filtered/fb_pop.Q30.poly.vcf.gz`
* `results/variants/gatk_joint/filtered/gatk_joint.Q30.poly.vcf.gz`

## Credits

PopFun utilizes the following open-source tools via [Bioconda](https://bioconda.github.io/) and [Biocontainers](https://biocontainers.pro/):

* [Fastp](https://github.com/OpenGene/fastp) [1.3.0] / [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) [0.12.1] / [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic) [0.40]
* [BWA-mem2](https://github.com/bwa-mem2/bwa-mem2) [2.3] / [Bowtie2](https://bowtie-mac.sourceforge.net/bowtie2/index.shtml) [2.5.5]
* [Samtools](http://www.htslib.org/) [1.23.1] / [BCFtools](http://samtools.github.io/bcftools/) [1.23.1]
* [GATK4](https://gatk.broadinstitute.org/hc/en-us) [4.6.2.0]
* [biobambam2 (bamsormadup)](https://gitlab.com/german.tischler/biobambam2) [2.0.185]
* [Sambamba](https://lomereiter.github.io/sambamba/) [1.0.1]
* [Mosdepth](https://github.com/brentp/mosdepth) [0.3.14]
* [FastDup](https://github.com/zzhofict/FastDup) [1.0.0]
* [Freebayes](https://github.com/freebayes/freebayes) [1.3.10]
* [RTG Tools](https://github.com/RealTimeGenomics/rtg-tools) [3.13] (`vcfeval` for optional ensemble matching)
* [BEDOPS](https://bedops.readthedocs.io/en/latest/) [2.4.42] (gff2bed)
* [Qualimap](http://qualimap.conesalab.org/) [2.3]
* [MultiQC](https://multiqc.info/) [1.35]
* [IQ-TREE](http://www.iqtree.org/) [2.4.0] / [MrBayes](http://nbisweden.github.io/MrBayes/) [3.2.7]

*This pipeline leverages the module patterns and configuration standards developed by the nf-core community.*

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributions and Support

Contributions are welcome through pull requests and issue reports.

* Bug reports and feature requests: [GitHub Issues](https://github.com/IdoBar/popfun/issues)
* Code contributions: [Pull Requests](https://github.com/IdoBar/popfun/pulls)

When reporting issues, please include:

* The exact command used to run the pipeline
* The profile and relevant parameter values
* The failing process name and error log snippet
* Your Nextflow version and execution environment (conda/docker/singularity/apptainer)

## Citations

If you use PopFun in your work, please cite the workflow framework and the software tools used in your run.

Recommended software citation (copy/paste):

> Bar, I. (2026). PopFun: Population-Scale Fungal Variant Calling Pipeline [Computer software]. Zenodo. [https://doi.org/10.5281/zenodo.20345437](https://doi.org/10.5281/zenodo.20345437)

The full bibliography for tools used in this pipeline is provided in [CITATIONS.md](CITATIONS.md).
Release-level changes are tracked in [CHANGELOG.md](CHANGELOG.md).
Public archival record (DOI): [10.5281/zenodo.20345437](https://doi.org/10.5281/zenodo.20345437).
This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Ewels, P. A., Peltzer, A., Fillinger, S., Patel, H., Alneberg, J., Wilm, A., Garcia, M. U., Di Tommaso, P., & Nahnsen, S. (2020). The nf-core framework for community-curated bioinformatics pipelines. Nature Biotechnology, 38(3), 276-278. doi:10.1038/s41587-020-0439-x
