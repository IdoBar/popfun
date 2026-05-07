process FREEBAYES_SPLIT_REGIONS {
    label 'sc_small'
    conda "bioconda::freebayes=1.3.10"
    container 'quay.io/biocontainers/freebayes:1.3.10--hbefcdb2_0'
    input:
        path ref_idx
        val chunk_size
    output:
        path "regions/*.regions.txt", emit: regions
    script:
    def chunk = (chunk_size ?: 100000).toString().trim()
    """
    mkdir -p regions

    fasta_generate_regions.py ${ref_idx} ${chunk} > target_regions.txt

    cut -f1 ${ref_idx} > chrom_list.txt
    while IFS= read -r chrom; do
        awk -v chr="\$chrom" -F '[:[:space:]]+' '\$1 == chr { print \$0 }' target_regions.txt > "regions/\${chrom}.regions.txt"
        if [ ! -s "regions/\${chrom}.regions.txt" ]; then
            awk -v chr="\$chrom" '\$1 == chr { printf "%s:1-%s\\n", \$1, \$2 }' ${ref_idx} > "regions/\${chrom}.regions.txt"
        fi
    done < chrom_list.txt
    """
}

process FREEBAYES_SPLIT_REGIONS_BAI {
    label 'sc_small'
    conda "conda-forge::python=3.11 conda-forge::numpy=1.23.5 conda-forge::scipy=1.10.1"
    container 'ghcr.io/idobar/popfun-bai-splitter@sha256:d9843bedf744e928c669b6b00ecd6d05d5652ab80adaf0638b4e68d32dc280fe'
    input:
        path ref_idx
        val target_data_size
        path bams
        path bais
        path split_script
    output:
        path "regions/*.regions.txt", emit: regions
    script:
    def target = target_data_size.toString().trim()
    """
    set -euo pipefail

    mkdir -p regions

    find -L . -maxdepth 1 -type f -name '*.bam' | LC_ALL=C sort > bam_paths.txt
    find -L . -maxdepth 1 -type f -name '*.bai' | LC_ALL=C sort > bai_paths.txt

    [ -s bam_paths.txt ] || { echo 'No staged BAM inputs discovered for FREEBAYES_SPLIT_REGIONS_BAI' >&2; exit 1; }
    [ -s bai_paths.txt ] || { echo 'No staged BAI inputs discovered for FREEBAYES_SPLIT_REGIONS_BAI' >&2; exit 1; }
    [ "\$(wc -l < bam_paths.txt)" -eq "\$(wc -l < bai_paths.txt)" ] || {
        echo 'BAM/BAI count mismatch in FREEBAYES_SPLIT_REGIONS_BAI' >&2
        exit 1
    }

    python3 "$split_script" -L bam_paths.txt -r $ref_idx -s ${target} > target_regions.txt

    cut -f1 $ref_idx > chrom_list.txt
    while IFS= read -r chrom; do
        awk -v chr="\$chrom" 'BEGIN{OFS=""} \$1 == chr && \$3 > \$2 { print \$1 ":" (\$2 + 1) "-" \$3 }' target_regions.txt > "regions/\${chrom}.regions.txt"
        if [ ! -s "regions/\${chrom}.regions.txt" ]; then
            awk -v chr="\$chrom" '\$1 == chr { printf "%s:1-%s\\n", \$1, \$2 }' $ref_idx > "regions/\${chrom}.regions.txt"
        fi
    done < chrom_list.txt
    """
}