process FREEBAYES {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::freebayes=1.3.10"
    container 'quay.io/biocontainers/freebayes:1.3.10--hbefcdb2_0'
    input:
        tuple val(meta), path(bam), path(bai)
        path ref
        path ref_idx
    output:
        path "${meta.id}.vcf.gz", emit: vcf
        path "${meta.id}.vcf.gz.tbi", emit: tbi
    script:
    def args = task.ext.args ?: ''
    def maxInnerThreads = (params.caller_inner_threads ?: 8) as Integer
    def threads = Math.max(1, Math.min((task.cpus ?: 1) as Integer, maxInnerThreads))
    """
    awk '{ print \$1 ":1-" \$2 }' $ref_idx > chromosome_regions.txt

    freebayes-parallel chromosome_regions.txt ${threads} -f $ref -p ${params.ploidy} $args $bam | bgzip -c > ${meta.id}.vcf.gz
    tabix -p vcf ${meta.id}.vcf.gz
    """
}

process FREEBAYES_POPULATION {
    tag "$meta.id"
    label 'mc_long'
    conda "bioconda::freebayes=1.3.10"
    container 'quay.io/biocontainers/freebayes:1.3.10--hbefcdb2_0'
    input:
        tuple val(meta), path(region_file), path(bams), path(bais), path(ref), path(ref_idx)
    output:
        tuple val(meta), path("${meta.id}.vcf.gz"), path("${meta.id}.vcf.gz.tbi"), emit: vcf
    script:
    def args = task.ext.args ?: ''
    def maxInnerThreads = (params.caller_inner_threads ?: 8) as Integer
    def threads = Math.max(1, Math.min((task.cpus ?: 1) as Integer, maxInnerThreads))
    """
    find -L . -type f -name '*.bam' | sort > bam_list.txt
    [ -s bam_list.txt ] || { echo 'No staged BAM inputs discovered for FREEBAYES_POPULATION' >&2; exit 1; }

    freebayes-parallel $region_file ${threads} -f $ref -p ${params.ploidy} $args -L bam_list.txt | bgzip -c > ${meta.id}.vcf.gz
    tabix -p vcf ${meta.id}.vcf.gz
    """
}

process GATK_HAPLOTYPECALLER {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_idx 
    path ref_dict 

    output:
    tuple val(meta), path("${meta.id}.g.vcf.gz"), path("${meta.id}.g.vcf.gz.tbi"), emit: gvcf

    script:
    def args = task.ext.args ?: ''
    def mem_per_job = Math.max(1, task.memory.toGiga().intdiv(task.cpus))
    def maxInnerThreads = (params.caller_inner_threads ?: 8) as Integer
    def threads = Math.max(1, Math.min((task.cpus ?: 1) as Integer, maxInnerThreads))
    """
    export NF_REF="${ref}"
    export NF_BAM="${bam}"
    export NF_PLOIDY="${params.ploidy}"
    export NF_ARGS="${args}"
    export NF_MEM="${mem_per_job}"

    cut -f1 ${ref_idx} | xargs -P ${threads} -I {} sh -c '
        gatk --java-options "-Xmx\${NF_MEM}g" HaplotypeCaller \
            -R "\${NF_REF}" -I "\${NF_BAM}" -L "{}" -O "{}.g.vcf.gz" \
            -ERC GVCF -ploidy "\${NF_PLOIDY}" --native-pair-hmm-threads 1 \${NF_ARGS} &&
        tabix -f -p vcf "{}.g.vcf.gz"
    '

    gather_args=\$(awk '{ printf " -I %s.g.vcf.gz", \$1 }' ${ref_idx})
    gatk --java-options "-Xmx${task.memory.toGiga()}g" GatherVcfs \$gather_args -O ${meta.id}.g.vcf.gz
    tabix -f -p vcf ${meta.id}.g.vcf.gz
    """
}

process GATK_COMBINEGVCFS {
    label 'sc_medium'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'

    input:
    path gvcfs
    path tbis
    path ref
    path ref_idx
    path ref_dict

    output:
    path "cohort.g.vcf.gz", emit: gvcf
    path "cohort.g.vcf.gz.tbi", emit: tbi

    script:
    // Dynamically build the -V arguments for all input gVCFs
    def input_args = gvcfs.collect { "-V $it" }.join(' ')
    """
    gatk --java-options "-Xmx${task.memory.toGiga()}g" CombineGVCFs \\
        -R $ref \\
        $input_args \\
        -O cohort.g.vcf.gz
    """
}

process GATK_GENOTYPEGVCFS {
    label 'sc_medium'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'

    input:
    path gvcf
    path tbi
    path ref
    path ref_idx
    path ref_dict

    output:
    path "joint_called.vcf.gz", emit: vcf
    path "joint_called.vcf.gz.tbi", emit: tbi

    script:
    """
    gatk --java-options "-Xmx${task.memory.toGiga()}g" GenotypeGVCFs \\
        -R $ref \\
        -V $gvcf \\
        -O joint_called.vcf.gz
    """
}

process FREEBAYES_GVCF {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::freebayes=1.3.10"
    container 'quay.io/biocontainers/freebayes:1.3.10--hbefcdb2_0'
    input:
        tuple val(meta), path(bam), path(bai)
        path ref
        path ref_idx
    output:
        tuple val(meta), path("${meta.id}.g.vcf.gz"), path("${meta.id}.g.vcf.gz.tbi"), emit: gvcf
    script:
    def args = task.ext.args ?: ''
    def maxInnerThreads = (params.caller_inner_threads ?: 8) as Integer
    def threads = Math.max(1, Math.min((task.cpus ?: 1) as Integer, maxInnerThreads))
    """
    awk '{ print \$1 ":1-" \$2 }' $ref_idx > chromosome_regions.txt

    freebayes-parallel chromosome_regions.txt ${threads} -f $ref -p ${params.ploidy} --gvcf $args $bam | bgzip -c > ${meta.id}.g.vcf.gz
    tabix -p vcf ${meta.id}.g.vcf.gz
    """
}

process GLNEXUS_COHORT {
    label 'mc_xlarge'
    conda "bioconda::glnexus=1.4.1 bioconda::bcftools=1.23.1 conda-forge::jemalloc"
    // Official GLnexus image; ships only glnexus_cli. Output raw BCF so no
    // bgzip/bcftools is needed inside this container. Downstream bcftools
    // processes handle BCF transparently.
    container 'ghcr.io/dnanexus-rnd/glnexus:v1.4.3'

    input:
    path gvcfs
    path tbis

    output:
    path "joint_called.bcf", emit: vcf

    script:
    def args = task.ext.args ?: ''
    def threads = Math.max(1, (task.cpus ?: 1) as Integer)
    def memGb = Math.max(1, (task.memory?.toGiga() ?: 8) as Integer)
    """
    # GLNexus performance tuning for large cohorts.
    ulimit -Sn 65536 || true

    if [ -z "\${LD_PRELOAD:-}" ]; then
        for jem in /usr/lib/x86_64-linux-gnu/libjemalloc.so /usr/lib64/libjemalloc.so /usr/lib/libjemalloc.so; do
            if [ -f "\${jem}" ]; then
                export LD_PRELOAD="\${jem}"
                break
            fi
        done
    fi

    printf '%s\n' $gvcfs > gvcf_list.txt

    # HapFun supports GLNexus only for GATK gVCFs.
    SELECTED_CONFIG="gatk"
    echo "Using GLNexus preset: \${SELECTED_CONFIG}" >&2

    if command -v numactl >/dev/null 2>&1; then
        numactl --interleave=all glnexus_cli --config \${SELECTED_CONFIG} --threads ${threads} --mem-gbytes ${memGb} --list gvcf_list.txt ${args} > joint_called.bcf
    else
        glnexus_cli --config \${SELECTED_CONFIG} --threads ${threads} --mem-gbytes ${memGb} --list gvcf_list.txt ${args} > joint_called.bcf
    fi
    """
}
