# HapFun: Haploid Fungal SNP Calling Pipeline

<p align="center">
    <img src="assets/hapfun.png" alt="HapFun logo" width="320" />
</p>

<!-- 
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](https://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/) -->
[![Repo](https://img.shields.io/badge/GitHub-IdoBar%2Fhapfun-181717?logo=github)](https://github.com/IdoBar/hapfun)
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg?labelColor=000000&logo=data:image/svg%2bxml;base64,PHN2ZyB3aWR0aD0iMjUxIiBoZWlnaHQ9IjI1MiIgdmlld0JveD0iMCAwIDI1MSAyNTIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+DQo8cGF0aCBkPSJNMCA0Ny42MzQ1QzM5LjQ1IDUwLjI1NDMgNzEuMDYgODEuOTQyMiA3My41NCAxMjEuNDNIMTE5LjYxQzExNy4wNSA1Ni40NzM5IDY0LjkzIDQuMjU3NDQgMCAxLjU1NzYyVjQ3LjYzNDVaIiBmaWxsPSIjMjJBRTYzIi8+DQo8cGF0aCBkPSJNNzMuOCAxMzEuOTM5QzcxLjE4IDE3MS4zODYgMzkuNDkgMjAyLjk5NCAwIDIwNS40NzRWMjUxLjU0MUM2NC45NiAyNDguOTgxIDExNy4xOCAxOTYuODY1IDExOS44OCAxMzEuOTM5SDczLjhaIiBmaWxsPSIjMjJBRTYzIi8+DQo8cGF0aCBkPSJNMTc2LjIwMSAxMjEuMTZDMTc4LjgyMSA4MS43MTIyIDIxMC41MTEgNTAuMTA0MyAyNTAuMDAxIDQ3LjYyNDVWMS41NTc2MkMxODUuMDQxIDQuMTE3NDQgMTMyLjgyMSA1Ni4yMzM5IDEzMC4xMjEgMTIxLjE2SDE3Ni4yMDFaIiBmaWxsPSIjMjJBRTYzIi8+DQo8cGF0aCBkPSJNMjUwLjAwMSAyMDUuNDY0QzIxMC41NTEgMjAyLjg0NSAxNzguOTQxIDE3MS4xNTcgMTc2LjQ2MSAxMzEuNjY5SDEzMC4zOTFDMTMyLjk1MSAxOTYuNjI1IDE4NS4wNzEgMjQ4Ljg0MiAyNTAuMDAxIDI1MS41NDFWMjA1LjQ2NFoiIGZpbGw9IiMyMkFFNjMiLz4NCjwvc3ZnPg==)](https://www.nextflow.io/)
[![run with conda](https://img.shields.io/badge/run%20with-conda-3EB049.svg?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed.svg?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity/apptainer](https://img.shields.io/badge/run%20with-singularity%2Fapptainer-F48B11.svg?labelColor=000000&logo=data:image/svg%2bxml;base64,PHN2ZyB3aWR0aD0iMjQ1IiBoZWlnaHQ9IjI0MCIgdmlld0JveD0iNjAgMCAzMTAgMjUwIiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgk8cGF0aCBkPSJtIDI3MC4xOCwyNTMuOTggYyAtMS44LC0xLjIgLTMuNCwtMyAtNC40LC01LjIgbCAtNTIuNiwtMTE3LjQgYyAtMi4yLC00LjggLTMuOCwtOC42IC01LjIsLTExLjYgLTIuMiwtNC40IC0yLjIsLTUuNiAtMi4yLC02LjQgMCwtMi4yIDAuOCwtMy44IDIuNiwtNC44IHYgLTQuNCBoIC00My4yIHYgNC40IGMgMC44LDAuNCAxLjIsMS4yIDEuOCwxLjggMC40LDAuOCAwLjgsMS44IDAuOCwzIDAsMS4yIC0wLjQsMyAtMS44LDUuNiAtMS4yLDIuNiAtMi42LDUuNiAtNC40LDkuNCBsIC01MS44LDExNyBjIC0wLjgsMS44IC0yLjIsNC40IC0zLjgsNy40IC0xLjgsMyAtNC44LDQuNCAtOC4yLDQuOCB2IDMuOCBoIDQ5LjYgdiAtMy44IGMgLTUuNiwwIC04LjIsLTIuMiAtOC4yLC01LjYgMCwtMS44IDAuOCwtNC44IDMsLTkgMS44LC0zLjQgMy44LC03LjggNS42LC0xMiAyNC42LDkuNCA1Mi4yLDEwIDc2LjgsMC44IDIuMiw0LjQgMy44LDguMiA1LjIsMTEuMiAxLjgsMy40IDIuNiw2LjQgMi42LDguNiAwLDIuMiAtMC44LDMuOCAtMi4yLDQuOCAtMS4yLDAuNCAtMi4yLDAuOCAtMy40LDEuMiB2IDMuOCBoIDUwLjQgdiAtMy44IGMgLTIuOCwtMS44IC01LjQsLTIuOCAtNywtMy42IHogbSAtMTExLjQsLTQ3IDI3LjYsLTYxLjQgMjgsNjIuMiBjIC0xOCw2IC0zNy40LDYgLTU1LjYsLTAuOCB6IiBmaWxsPSJ3aGl0ZSIvPiA8cGF0aCBkPSJtIDg5Ljc4LDE0MC45OCBjIDAsLTkgMS4yLC0xNy42IDMuNCwtMjYuNCBsIC0yOCwtMTIuNiBjIC0zLjgsMTIgLTYsMjQuNiAtNiwzNy42IDAsMzUgMTQuMiw2OC42IDM5LjgsOTIuOCBsIDEuOCwtMy40IDExLjIsLTI1LjQgYyAtMTMuNiwtMTcuNCAtMjIuMiwtMzkgLTIyLjIsLTYyLjYgeiIgZmlsbD0iIzkzOTU5OCIvPiA8cGF0aCBkPSJtIDMxMC4xOCwxMDIuNTggLTI4LDEyLjYgYyAyLjIsOC4yIDMuNCwxNi44IDMuNCwyNS44IDAsMjMuOCAtOC42LDQ1LjggLTIyLjgsNjIuNiBsIDExLjYsMjUuNCAxLjgsMy40IGMgMjUuNCwtMjQuMiAzOS44LC01Ny44IDM5LjgsLTkyLjggLTAuMiwtMTIuNCAtMi4yLC0yNSAtNS44LC0zNyB6IiBmaWxsPSIjRjc5NDIxIi8+IDxwYXRoIGQ9Im0gNzEuMTgsODYuOTggMjcuNiwxMi42IGMgMTQuNiwtMzEgNDQuOCwtNTMgODAuMiwtNTYuMiB2IC0zMC42IGMgLTQ2LDIuNiAtODguNCwzMS40IC0xMDcuOCw3NC4yIHoiIGZpbGw9IiMxRTk1RDMiLz4gPHBhdGggZD0ibSAzMDQuMTgsODYuOTggYyAtMTkuNCwtNDIuOCAtNjEuOCwtNzEuNiAtMTA4LjQsLTc0LjYgdiAzMC42IGMgMzUuOCwzIDY2LDI1IDgwLjYsNTYuMiB6IiBmaWxsPSIjNkZCNTQ0Ii8+PC9zdmc+)](https://sylabs.io/docs/)

## Introduction

**HapFun** (Haploid Fungal SNP Calling) is a highly scalable bioinformatics pipeline for identifying single nucleotide polymorphisms (SNPs) and insertions/deletions (Indels) from whole-genome sequencing (WGS) data of clonal haploid fungal isolates.

Built using Nextflow DSL2 and strictly adhering to nf-core data structures (including meta maps), HapFun bridges the gap between raw sequencing reads and high-quality, filtered variant calls. It is highly parameterized, automatically handles missing reference indices, and includes a unique parallel track for estimating error rates across replicate libraries of same samples.

## Pipeline Summary

By default, **HapFun** performs the following steps:

1. **Reference Preparation**: Automatically decompresses the reference (if provided as `.fasta.gz`) and generates missing `.fai`, `.dict`, and aligner index directories (`bwa-mem2` or `bowtie2`) if not provided by the user.
2. **Read QC & Trimming**: `fastp` (default) OR `Trimmomatic` (with `FastQC`).
3. **Read Alignment**: `bwa-mem2` (default) or `bowtie2`.
4. **BAM Processing**:
    * Merges multiple libraries belonging to the same sample (`samtools`).
    * Marks optical/PCR duplicates (`bamsormadup` by default, with optional `GATK MarkDuplicates`, `sambamba`, or `FastDup`).
5. **Alignment QC**: `Qualimap` (Supports optional `.gff`/`.bed` annotations for targeted region metrics).
6. **Variant Calling**: `Freebayes` (Population mode default) or `GATK HaplotypeCaller`.
    * *Supports Freebayes population-level calling, or individual sample calling + merging.*
    * *Population mode can split chromosomes into multiple sub-regions for finer `freebayes-parallel` fan-out using fixed-size chunks from `fasta_generate_regions.py`.*
    * *After global region generation, per-chromosome region files are produced so each population shard remains chromosome-scoped for concatenation.*
    * *Alternative cohort-scale gVCF genotyping via `glnexus_cli` is available with `--gvcf_joint_caller glnexus`.*
    * *When using `--gvcf_joint_caller glnexus` with `--caller freebayes`, HapFun switches Freebayes to per-sample gVCF output and auto-selects the GLNexus preset via `glnexus_cli --config` according to gVCF source (`gatk` or `freebayes`).*
7. **Error Estimation (Optional)**: If `--error_estimate true` is flagged, the pipeline automatically separates replicate libraries, calls variants on them independently, and calculates genotype discordance rates using a custom Python module. The raw per-library VCFs used in this comparison are also retained in `results/variants/error_estimate_libraries/`.
8. **Population Genetics (Optional)**: If `--popgen true`, HapFun performs PCA (PC1-PC3) and constructs a phylogenetic tree from the final cohort VCF (regardless of variant caller and calling mode), then adds both panels to MultiQC. If a `pop` column is present in the samplesheet, it is used to color PCA markers and tree nodes.
9. **Variant Filtering**: Strictly filters VCFs based on Depth (DP), Quality (QUAL), and polymorphism, while recalculating INFO tags (`bcftools +fill-tags`). Outputs distinct `.snps.vcf` and `.indels.vcf` files.
10. **Final Reporting**: Aggregates QC metrics and software versions across all steps into a single HTML report (`MultiQC`).

## Quick Start

1. Install [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html#installation) (>=22.10.1).
2. Install [Conda](https://docs.conda.io/en/latest/), [Docker](https://docs.docker.com/engine/installation/), or [Singularity/Apptainer](https://sylabs.io/guides/3.0/user-guide/).
   * *Note: Apptainer is only supported from Nextflow version 22.11.0-edge and later.*
3. Create a `samplesheet.csv` with your input data.
    * *Note: Rows with the exact same `sample` ID but different `library` IDs will be automatically merged post-alignment.*
    * *Optional: Add a `pop` column with population/group labels. This is used by the population genetics module to color PCA markers and phylogenetic tree nodes.*

    ```csv
        sample,library,fq1,fq2,pop
        FungusA,Lib1,data/A_L1_1.fq.gz,data/A_L1_2.fq.gz,Pop_1
        FungusA,Lib2,data/A_L2_1.fq.gz,data/A_L2_2.fq.gz,Pop_1
        FungusB,Lib1,data/B_L1_1.fq.gz,data/B_L1_2.fq.gz,Pop_2
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

    **Quick test run** (using bundled test data):

    ```bash
        nextflow run main.nf -profile test,conda
    ```

## Advanced Usage

HapFun allows you to bypass expensive indexing steps by providing pre-built directories, and allows fine-grained control over tool arguments.

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
* `--caller`: `freebayes` (default) or `gatk`
* `--gvcf_joint_caller`: Cohort genotyper for per-sample gVCFs: `gatk` (default) or `glnexus`.
* `--glnexus_config`: Optional override value passed to `glnexus_cli --config` when `--gvcf_joint_caller glnexus` is used. If omitted, HapFun auto-selects based on gVCF source (`gatk` or `freebayes`).
* `--markdup_tool`: `bamsormadup` (default), `gatk`, `sambamba`, or `fastdup`
* `--freebayes_mode`: `population` (default) or `individual`
* `--freebayes_chunk_size`: Chunk size passed to `fasta_generate_regions.py` for splitting genomic regions in Freebayes population-mode. (Default: `100000`).
    *Note: Freebayes population mode can be time-intensive for large cohorts (roughly >200 samples, depending on sequencing depth).*
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
* `--freebayes_args`: Additional arguments passed to Freebayes (Default: `--genotype-qualities`). Keep this flag enabled so `GQ` fields are emitted for downstream genotype-based filtering. In population mode, these arguments are forwarded to each chromosome-level `freebayes-parallel` task.
* `--glnexus_args`: Additional arguments passed to `glnexus_cli` (Default: empty).
* `--caller_inner_threads`: Maximum within-task chromosome fan-out for `FREEBAYES`, `FREEBAYES_POPULATION`, and `GATK_HAPLOTYPECALLER` (Default: `8`). Effective threads per task are `min(task.cpus, caller_inner_threads)`.

When `--gvcf_joint_caller glnexus` is enabled, HapFun applies GLNexus performance guidance for large cohorts by setting explicit thread/memory budgets, raising open-file limits, enabling NUMA interleave when available, and attempting `jemalloc` preload when it is present.

**VCF Filtering:**

Note: Genotype-based filtering relies on valid `GQ` fields. By default, HapFun enables Freebayes `--genotype-qualities` (via `--freebayes_args`) so genotype qualities are emitted and filtering behaves as expected.

* `--filter_qual`: Minimum QUAL score (Default: `30`)
* `--filter_min_dp`: Minimum Depth (Default: `10`)
* `--filter_ind_dp`: Minimum individual genotype depth (Default: `7`)
* `--mask_hetero`: Mask heterozygous genotypes (`GT=='het'`) during filtering (Default: `true`). Requires diploid variant calling (`--ploidy 2`).

## Output Directory Structure

Upon completion, the `--outdir` will contain the following structured directories:

```text
    results/
    ├── aligned/              # Final, merged, deduplicated BAM files
    ├── error_estimates/      # CSV reports of replicate discordance rates
    ├── multiqc/              # Aggregated HTML QC report
    ├── population_genetics/  # PCA, phylogenetic tree, and intermediate population-genetics outputs
    ├── qc/                   # Individual QC reports (Fastp, FastQC, Qualimap, BCFtools)
    └── variants/
        ├── error_estimate_libraries/ # Raw per-library VCFs used for error-rate estimation (`--error_estimate true`)
        ├── gvcfs/            # Per-sample Freebayes gVCFs when `--gvcf_joint_caller glnexus` with Freebayes
        ├── gatk_gvcfs/       # Per-sample GATK gVCFs
        ├── glnexus_cohort/   # GLNexus cohort-level joint-called VCF
        ├── individual/       # Raw per-sample VCFs (if using individual mode)
        ├── merged/           # Raw aggregated VCF (if using individual mode)
        ├── population/       # Raw aggregated VCF from chromosome-parallel Freebayes population mode
        └── filtered/         # FINAL processed VCFs (SNPs, Indels, and combined)
```

## Credits

HapFun utilizes the following open-source tools via [Bioconda](https://bioconda.github.io/) and [Biocontainers](https://biocontainers.pro/):

* [Fastp](https://github.com/OpenGene/fastp) [1.3.0] / [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) [0.12.1] / [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic) [0.40]
* [BWA-mem2](https://github.com/bwa-mem2/bwa-mem2) [2.3] / [Bowtie2](https://bowtie-mac.sourceforge.net/bowtie2/index.shtml) [2.5.5]
* [Samtools](http://www.htslib.org/) [1.23.1] / [BCFtools](http://samtools.github.io/bcftools/) [1.23.1]
* [GATK4](https://gatk.broadinstitute.org/hc/en-us) [4.6.2.0]
* [biobambam2 (bamsormadup)](https://gitlab.com/german.tischler/biobambam2) [2.0.185]
* [Sambamba](https://lomereiter.github.io/sambamba/) [1.0.1]
* [FastDup](https://github.com/zzhofict/FastDup) [1.0.0]
* [Freebayes](https://github.com/freebayes/freebayes) [1.3.10]
* [GLNexus](https://github.com/dnanexus-rnd/GLnexus) [1.4.1]
* [BEDOPS](https://bedops.readthedocs.io/en/latest/) [2.4.42] (gff2bed)
* [Qualimap](http://qualimap.conesalab.org/) [2.3]
* [MultiQC](https://multiqc.info/) [1.33]
* [IQ-TREE](http://www.iqtree.org/) [2.4.0] / [MrBayes](http://nbisweden.github.io/MrBayes/) [3.2.7]

*This pipeline leverages the module patterns and configuration standards developed by the nf-core community.*

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributions and Support

Contributions are welcome through pull requests and issue reports.

* Bug reports and feature requests: [GitHub Issues](https://github.com/IdoBar/hapfun/issues)
* Code contributions: [Pull Requests](https://github.com/IdoBar/hapfun/pulls)

When reporting issues, please include:

* The exact command used to run the pipeline
* The profile and relevant parameter values
* The failing process name and error log snippet
* Your Nextflow version and execution environment (conda/docker/singularity/apptainer)

## Citations

If you use HapFun in your work, please cite the workflow framework and the software tools used in your run.

The full bibliography for tools used in this pipeline is provided in [CITATIONS.md](CITATIONS.md).
This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Ewels, P. A., Peltzer, A., Fillinger, S., Patel, H., Alneberg, J., Wilm, A., Garcia, M. U., Di Tommaso, P., & Nahnsen, S. (2020). The nf-core framework for community-curated bioinformatics pipelines. Nature Biotechnology, 38(3), 276-278. doi:10.1038/s41587-020-0439-x
