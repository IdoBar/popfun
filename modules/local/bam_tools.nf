process SAMTOOLS_MERGE {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::samtools=1.23.1"
    container 'quay.io/biocontainers/samtools:1.23.1--ha83d96e_0'
    input: tuple val(meta), path(bams)
    output: tuple val(meta), path("${meta.id}.merged.bam"), emit: merged_bam
    script:
    """
    samtools merge -@ ${task.cpus} ${meta.id}.merged.bam $bams
    """
}

process MARK_DUPLICATES {
    tag "$meta.id"
    label 'sc_medium'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'
    input: tuple val(meta), path(bam)
    output:
        tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bai"), emit: dedup_bam
        path "${meta.id}.metrics.txt", emit: metrics 
    script:
    """
    gatk MarkDuplicates -I "$bam" -O "${meta.id}.dedup.bam" -M "${meta.id}.metrics.txt" --CREATE_INDEX true --READ_NAME_REGEX null
    """
}

process MARK_DUPLICATES_BAMSORMADUP {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::biobambam=2.0.185"
    container 'quay.io/biocontainers/biobambam:2.0.185--h85de650_1'
    input: tuple val(meta), path(bam)
    output:
        tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bai"), emit: dedup_bam
        path "${meta.id}.metrics.txt", emit: metrics
    script:
    """
    bamcollate2 inputformat=bam outputformat=bam level=1 < "$bam" | \
    bamsormadup SO=coordinate inputformat=bam level=1 threads=${task.cpus} M="${meta.id}.metrics.txt" > "${meta.id}.dedup.bam"
    bamindex < "${meta.id}.dedup.bam" > "${meta.id}.dedup.bai"
    """
}

process MARK_DUPLICATES_SAMBAMBA {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::sambamba=1.0.1"
    container 'quay.io/biocontainers/sambamba:1.0.1--h6f6fda4_1'
    input: tuple val(meta), path(bam)
    output:
        tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bai"), emit: dedup_bam
        path "${meta.id}.sambamba_markdup.log", emit: metrics
    script:
    """
    sambamba markdup -t ${task.cpus} "$bam" "${meta.id}.dedup.bam" 2> "${meta.id}.sambamba_markdup.log"
    sambamba index -t ${task.cpus} "${meta.id}.dedup.bam" "${meta.id}.dedup.bai"
    """
}

process MARK_DUPLICATES_FASTDUP {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::fastdup=1.0.0 bioconda::samtools=1.23.1"
    container 'ghcr.io/idobar/fastdup:latest'
    input: tuple val(meta), path(bam)
    output:
        tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bai"), emit: dedup_bam
        path "${meta.id}.metrics.txt", emit: metrics
    script:
    """
    fastdup --input "$bam" --output "${meta.id}.dedup.bam" --metrics "${meta.id}.metrics.txt" --num-threads ${task.cpus}
    samtools index -@ ${task.cpus} "${meta.id}.dedup.bam" "${meta.id}.dedup.bai"
    """
}

process QUALIMAP {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::qualimap=2.3"
    container 'quay.io/biocontainers/qualimap:2.3--hdfd78af_0'

    input:
    tuple val(meta), path(bam), path(bai)
    path bed // Optional annotation file

    output:
    // Standardized nf-core tuple output, emitting the whole directory
    tuple val(meta), path("${meta.id}_qualimap"), emit: results 

    script:
    // Only append the flag if a bed file was actually staged
    def feature_arg = bed.name != 'NO_FILE' ? "-gff \"$bed\"" : ""
    
    """
    unset DISPLAY
    qualimap bamqc \\
        -bam "$bam" \\
        -nt ${task.cpus} \\
        $feature_arg \\
        -outdir "${meta.id}_qualimap" \\
        --java-mem-size=4G
    """
}