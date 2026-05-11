// Save as: modules/local/reference_prep.nf

process DECOMPRESS_FASTA {
    tag "$fasta"
    label 'sc_small'
    conda "bioconda::samtools=1.23.1"
    container 'quay.io/biocontainers/samtools:1.23.1--ha83d96e_0'

    input:
    path fasta

    output:
    path "reference.decompressed.fa", emit: fasta

    script:
    """
    gunzip -c "$fasta" > reference.decompressed.fa
    """
}

process SAMTOOLS_FAIDX {
    tag "$fasta"
    label 'sc_small'
    conda "bioconda::samtools=1.23.1"
    container 'quay.io/biocontainers/samtools:1.23.1--ha83d96e_0'

    input:
    path fasta

    output:
    path "*.fai", emit: fai

    script:
    """
    samtools faidx "$fasta"
    """
}

process GATK_DICTIONARY {
    tag "$fasta"
    label 'sc_small'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'

    input:
    path fasta

    output:
    path "*.dict", emit: dict

    script:
    // Support .fa/.fasta plus optional .gz suffix when deriving dictionary name.
    def dict_name = fasta.name.replaceAll(/(?i)\.(fa|fasta)(\.gz)?$/, ".dict")
    
    """
    gatk CreateSequenceDictionary -R "$fasta" -O "$dict_name"
    """
}

process BWA_INDEX {
    tag "$fasta"
    label 'sc_medium'
    conda "bioconda::bwa-mem2=2.3"
    container 'quay.io/biocontainers/bwa-mem2:2.3--he70b90d_0'

    input: path fasta
    output: path "bwa_index", emit: index

    script:
    """
    mkdir bwa_index
    # Symlink the fasta into the dir so bwa-mem2 writes indices next to it
    ref_real_path=\$(readlink -f "$fasta")
    ln -s "\$ref_real_path" "bwa_index/${fasta.name}"
    bwa-mem2 index "bwa_index/${fasta.name}"
    """
}

process BOWTIE2_INDEX {
    tag "$fasta"
    label 'mc_medium'
    conda "bioconda::bowtie2=2.5.5"
    container 'quay.io/biocontainers/bowtie2:2.5.5--ha27dd3b_0'

    input: path fasta
    output: path "bowtie2_index", emit: index

    script:
    """
    mkdir bowtie2_index
    bowtie2-build --threads ${task.cpus} "$fasta" "bowtie2_index/${fasta.name}"
    """
}