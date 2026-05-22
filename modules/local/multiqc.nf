// Save as: modules/local/multiqc.nf

process GENERATE_SOFTWARE_VERSIONS_MQC {
        label 'sc_small'

        input:
        val trimmer
        val aligner
        val caller
        val markdup_tool
        val annotation
        val popgen

        output:
        path "popfun_mqc_versions.yml", emit: versions

        script:
        """
        cat > popfun_mqc_versions.yml << 'YAML'
fastp: "1.3.0"
fastqc: "0.12.1"
trimmomatic: "0.40"
bwa_mem2: "2.3"
bowtie2: "2.5.5"
samtools: "1.23.1"
bcftools: "1.23.1"
gatk4: "4.6.2.0"
biobambam2: "2.0.185"
sambamba: "1.0.1"
mosdepth: "0.3.14"
fastdup: "1.0.0"
freebayes: "1.3.10"
bedops: "2.4.42"
qualimap: "2.3"
multiqc: "1.33"
iqtree: "2.4.0"
mrbayes: "3.2.7"
YAML
        """
}

process MULTIQC {
    label 'sc_small'
    conda "bioconda::multiqc=1.33"
    container 'quay.io/biocontainers/multiqc:1.33--pyhdfd78af_0'

    input: 
    // Keep each staged input under a unique subfolder to avoid basename collisions.
    path multiqc_files, stageAs: 'multiqc_inputs??/*'
    path multiqc_config
    path multiqc_logo   // staged alongside config so relative path in YAML resolves

    output:
        path "multiqc_report.html", emit: report
        path "*_data", emit: data

    script:
    """
    multiqc -n multiqc_report.html -c "$multiqc_config" .
    """
}