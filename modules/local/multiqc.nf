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
        path "software_versions_mqc.yml", emit: versions

        script:
        def check = '✓'
        def use_fastp = trimmer == 'fastp' ? check : ''
        def use_fastqc = trimmer == 'trimmomatic' ? check : ''
        def use_trimmomatic = trimmer == 'trimmomatic' ? check : ''
        def use_bwa = aligner == 'bwa-mem2' ? check : ''
        def use_bowtie2 = aligner == 'bowtie2' ? check : ''
        def use_gatk = (caller == 'gatk' || markdup_tool == 'gatk') ? check : ''
        def use_biobambam2 = markdup_tool == 'bamsormadup' ? check : ''
        def use_sambamba = markdup_tool == 'sambamba' ? check : ''
        def use_fastdup = markdup_tool == 'fastdup' ? check : ''
        def use_freebayes = caller == 'freebayes' ? check : ''
        def use_bedops = (annotation && (annotation.toString().endsWith('.gff') || annotation.toString().endsWith('.gff3'))) ? check : ''
        def use_popgen_tools = popgen ? check : ''
        """
        cat > software_versions_mqc.yml << 'YAML'
id: software_versions
section_name: "Software Versions"
description: "Tool versions used by PopFun."
plot_type: table
pconfig:
    id: popfun_software_versions_table
    title: "PopFun: Software Versions"
    col1_header: "Tool"
    sort_rows: false
headers:
    version:
        title: "Version"
    used:
        title: "Used"
data:
    fastp:
        version: "1.3.0"
        used: "${use_fastp}"
    fastqc:
        version: "0.12.1"
        used: "${use_fastqc}"
    trimmomatic:
        version: "0.40"
        used: "${use_trimmomatic}"
    bwa_mem2:
        version: "2.3"
        used: "${use_bwa}"
    bowtie2:
        version: "2.5.5"
        used: "${use_bowtie2}"
    samtools:
        version: "1.23.1"
        used: "✓"
    bcftools:
        version: "1.23.1"
        used: "✓"
    gatk4:
        version: "4.6.2.0"
        used: "${use_gatk}"
    biobambam2:
        version: "2.0.185"
        used: "${use_biobambam2}"
    sambamba:
        version: "1.0.1"
        used: "${use_sambamba}"
    fastdup:
        version: "1.0.0"
        used: "${use_fastdup}"
    freebayes:
        version: "1.3.10"
        used: "${use_freebayes}"
    bedops:
        version: "2.4.42"
        used: "${use_bedops}"
    qualimap:
        version: "2.3"
        used: "✓"
    multiqc:
        version: "1.33"
        used: "✓"
    iqtree:
        version: "2.4.0"
        used: "${use_popgen_tools}"
    mrbayes:
        version: "3.2.7"
        used: "${use_popgen_tools}"
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
    multiqc -n multiqc_report.html -c $multiqc_config .
    """
}