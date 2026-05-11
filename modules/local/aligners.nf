// Save as: modules/local/aligners.nf

process BWA_ALIGN {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_large'
    conda "bioconda::bwa-mem2=2.3"
    container 'quay.io/biocontainers/bwa-mem2:2.3--he70b90d_0'
    
    input:
        tuple val(meta), path(read1), path(read2)
        path index_dir
        val prefix
        
    output: tuple val(meta), path("*.sam"), emit: sam
    
    script:
    def args = task.ext.args ?: ''
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    def rg = "@RG\\tID:${meta.id}.${unitId}\\tSM:${meta.id}\\tLB:${unitId}\\tPL:ILLUMINA"
    """
    bwa-mem2 mem -t ${task.cpus} -R '$rg' $args "${index_dir}/${prefix}" "$read1" "$read2" > "${unitId}.sam"
    """
}

process BOWTIE2_ALIGN {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_large'
    conda "bioconda::bowtie2=2.5.5"
    container 'quay.io/biocontainers/bowtie2:2.5.5--ha27dd3b_0'

    input:
        tuple val(meta), path(read1), path(read2)
        path index_dir
        val prefix

    output: tuple val(meta), path("*.sam"), emit: sam

    script:
    def args = task.ext.args ?: ''
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    bowtie2 -x "${index_dir}/${prefix}" -1 "$read1" -2 "$read2" -p ${task.cpus} $args \\
        --rg-id ${meta.id}.${unitId} --rg SM:${meta.id} --rg LB:${unitId} --rg PL:ILLUMINA > "${unitId}.sam"
    """
}

process SAMTOOLS_SORT_ALIGN {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::samtools=1.23.1"
    container 'quay.io/biocontainers/samtools:1.23.1--ha83d96e_0'

    input:
        tuple val(meta), path(sam)

    output:
        tuple val(meta), path("*.sorted.bam"), emit: bam

    script:
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    samtools sort -@ ${task.cpus} -o "${unitId}.sorted.bam" "$sam"
    """
}