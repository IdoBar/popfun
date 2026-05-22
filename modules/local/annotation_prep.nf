// Save as: modules/local/annotation_prep.nf

process GFF_TO_BED {
    tag "$gff"
    label 'sc_small'
    conda "bioconda::bedops=2.4.42"
    container 'quay.io/biocontainers/bedops:2.4.42--hd6d6fdc_1'

    input:
    path gff

    output:
    path "*.bed", emit: bed

    script:
    // Safely strip the extension and replace with .bed
    def bed_name = gff.name.replaceAll(/\.gff(3)?$/, ".bed")
    """
    tr -d '\r' < "$gff" \
        | gff2bed \
        | awk 'BEGIN { OFS = "\t" } NF >= 3 && \$1 !~ /^#/ && \$1 != "track" && \$1 != "browser" { print }' \
        > "$bed_name"

    [ -s "$bed_name" ] || { echo 'No valid BED records were produced from annotation input' >&2; exit 1; }
    """
}