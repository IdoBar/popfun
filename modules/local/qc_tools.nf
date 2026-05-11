// Save as: modules/local/qc_tools.nf

process FASTP {
    tag "${meta.id}_${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::fastp=1.3.0"
    container 'quay.io/biocontainers/fastp:1.3.0--h43da1c4_0'
    
    input:
        tuple val(meta), path(read1), path(read2)
    output:
        tuple val(meta), path("*_1.fastp.fq.gz"), path("*_2.fastp.fq.gz"), emit: trimmed_reads
        path "*.json", emit: json 
        path "*.html", emit: html
    script:
    def args = task.ext.args ?: ''
    def libraryId = meta.unit_id ?: meta.library ?: meta.id
    def reportId = "${meta.id}_${libraryId}".replaceAll(/[^A-Za-z0-9._-]+/, '_')
    """
    fastp --in1 "$read1" --in2 "$read2" --out1 "${reportId}_1.fastp.fq.gz" --out2 "${reportId}_2.fastp.fq.gz" --json "${reportId}.fastp.json" --html "${reportId}.fastp.html" --thread ${task.cpus} $args
    """
}

process FASTQC {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::fastqc=0.12.1"
    container 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0'
    
    input:
        tuple val(meta), path(read1), path(read2)
    output: path "*.{html,zip}", emit: results
    
    script:
    """
    fastqc -t ${task.cpus} -q "$read1" "$read2"
    """
}

process TRIMMOMATIC {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::trimmomatic=0.40"
    container 'quay.io/biocontainers/trimmomatic:0.40--hdfd78af_0'
    
    input:
        tuple val(meta), path(read1), path(read2)
    output:
        tuple val(meta), path("*_1.paired.fq.gz"), path("*_2.paired.fq.gz"), emit: trimmed_reads
        path "*.trim.log", emit: log 
        
    script:
    def args = task.ext.args ?: ''
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    trimmomatic PE -threads ${task.cpus} \\
    "$read1" "$read2" \
    "${unitId}_1.paired.fq.gz" "${unitId}_1.unpaired.fq.gz" \
    "${unitId}_2.paired.fq.gz" "${unitId}_2.unpaired.fq.gz" \
    $args \
    2> "${unitId}.trim.log"
    """
}