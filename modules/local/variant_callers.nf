process FREEBAYES {
    tag "$meta.id"
    label 'mc_medium'
    conda "bioconda::freebayes=1.3.10"
    container 'quay.io/biocontainers/freebayes:1.3.10--hbefcdb2_0'
    input:
        tuple val(meta), path(bam), path(bai), path(region_files), path(ref)
    output:
        path "${meta.id}.vcf.gz", emit: vcf
        path "${meta.id}.vcf.gz.tbi", emit: tbi
        path "${meta.id}.freebayes_diagnostics/*.tsv", optional: true, emit: diagnostics
    script:
    def args = task.ext.args ?: ''
    def threads = Math.max(1, (task.cpus ?: 1) as Integer)
    def diagnosticsDir = "${meta.id}.freebayes_diagnostics"
    def debugEnabled = params.freebayes_debug ? 'true' : 'false'
    """
    set -euo pipefail

    find -L . -type f -name '*.regions.txt' | LC_ALL=C sort > region_file_paths.txt
    [ -s region_file_paths.txt ] || { echo 'No staged region files discovered for FREEBAYES' >&2; exit 1; }
    xargs cat < region_file_paths.txt > chromosome_regions.txt

    [ -s chromosome_regions.txt ] || { echo 'No Freebayes regions generated' >&2; exit 1; }

    mkdir -p chunks
    if [ "${debugEnabled}" = 'true' ]; then
        mkdir -p ${diagnosticsDir}/stderr ${diagnosticsDir}/metrics
    fi
    export NF_REF="$ref"
    export NF_PLOIDY="${params.ploidy}"
    export NF_ARGS="${args}"
    export NF_BAM="$bam"
    export NF_DIAG_DIR="${diagnosticsDir}"
    export NF_DEBUG="${debugEnabled}"

    set +e
    awk 'NF { printf "%s chunks/%08d.vcf\\n", \$0, NR }' chromosome_regions.txt \
        | xargs -r -n 2 -P ${threads} sh -c '
            region="\$1"
            chunk_vcf="\$2"
            chunk_id=\$(basename "\${chunk_vcf%.vcf}")
            if [ "\$NF_DEBUG" = "true" ]; then
                stderr_log="\$NF_DIAG_DIR/stderr/\${chunk_id}.stderr.log"
                metric_file="\$NF_DIAG_DIR/metrics/\${chunk_id}.tsv"
            else
                stderr_log=/dev/null
                metric_file=''
            fi
            start_epoch=\$(date +%s)
            freebayes -f "\$NF_REF" -p "\$NF_PLOIDY" \$NF_ARGS "\$NF_BAM" --region "\$region" > "\$chunk_vcf" 2> "\$stderr_log"
            status=\$?
            end_epoch=\$(date +%s)
            duration_seconds=\$((end_epoch - start_epoch))
            if [ "\$NF_DEBUG" = "true" ]; then
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                    "\$chunk_id" "\$region" "\$status" "\$start_epoch" "\$end_epoch" "\$duration_seconds" "\$chunk_vcf" "\$stderr_log" > "\$metric_file"
            fi
            exit "\$status"
        ' sh
    xargs_status=\$?
    set -e

    if [ "${debugEnabled}" = 'true' ]; then
        find ${diagnosticsDir}/metrics -type f -name '*.tsv' | LC_ALL=C sort > metric_files.list
        [ -s metric_files.list ] || { echo 'No Freebayes diagnostic metrics were produced' >&2; exit 1; }

        printf 'chunk_id\tregion\texit_status\tstart_epoch\tend_epoch\tduration_seconds\tvcf_path\tstderr_log\n' > ${diagnosticsDir}/region_runtime.tsv
        xargs cat < metric_files.list >> ${diagnosticsDir}/region_runtime.tsv

        printf 'chunk_id\tregion\texit_status\tstart_epoch\tend_epoch\tduration_seconds\tvcf_path\tstderr_log\n' > ${diagnosticsDir}/slowest_regions.tsv
        tail -n +2 ${diagnosticsDir}/region_runtime.tsv | LC_ALL=C sort -t "\$(printf '\t')" -k6,6nr | awk 'NR <= 10' >> ${diagnosticsDir}/slowest_regions.tsv
    fi

    if [ "\$xargs_status" -ne 0 ]; then
        echo 'One or more Freebayes chunk calls failed; see freebayes diagnostics for details' >&2
        exit "\$xargs_status"
    fi

    find chunks -type f -name '*.vcf' | LC_ALL=C sort > chunk_vcfs.list
    [ -s chunk_vcfs.list ] || { echo 'No Freebayes chunk outputs were produced' >&2; exit 1; }

    set +e
    set +o pipefail
    xargs cat < chunk_vcfs.list | vcffirstheader | vcfstreamsort -w 1000 | vcfuniq > merged.vcf
    merge_status=\$?
    set -o pipefail
    set -e
    if [ "\$merge_status" -ne 0 ]; then
        exit "\$merge_status"
    fi

    bgzip -c merged.vcf > ${meta.id}.vcf.gz
    tabix -p vcf ${meta.id}.vcf.gz
    rm -f merged.vcf chunk_vcfs.list
    rm -rf chunks
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
        path "${meta.id}.freebayes_diagnostics/*.tsv", optional: true, emit: diagnostics
    script:
    def args = task.ext.args ?: ''
    def threads = Math.max(1, (task.cpus ?: 1) as Integer)
    def diagnosticsDir = "${meta.id}.freebayes_diagnostics"
    def debugEnabled = params.freebayes_debug ? 'true' : 'false'
    """
    set -euo pipefail

    find -L . -type f -name '*.bam' | LC_ALL=C sort > bam_list.txt
    [ -s bam_list.txt ] || { echo 'No staged BAM inputs discovered for FREEBAYES_POPULATION' >&2; exit 1; }

    mkdir -p chunks
    if [ "${debugEnabled}" = 'true' ]; then
        mkdir -p ${diagnosticsDir}/stderr ${diagnosticsDir}/metrics
    fi
    export NF_REF="$ref"
    export NF_PLOIDY="${params.ploidy}"
    export NF_ARGS="${args}"
    export NF_BAM_LIST="\$(pwd)/bam_list.txt"
    export NF_DIAG_DIR="${diagnosticsDir}"
    export NF_DEBUG="${debugEnabled}"

    set +e
    awk 'NF { printf "%s chunks/%08d.vcf\\n", \$0, NR }' "$region_file" \
        | xargs -r -n 2 -P ${threads} sh -c '
            region="\$1"
            chunk_vcf="\$2"
            chunk_id=\$(basename "\${chunk_vcf%.vcf}")
            if [ "\$NF_DEBUG" = "true" ]; then
                stderr_log="\$NF_DIAG_DIR/stderr/\${chunk_id}.stderr.log"
                metric_file="\$NF_DIAG_DIR/metrics/\${chunk_id}.tsv"
            else
                stderr_log=/dev/null
                metric_file=''
            fi
            start_epoch=\$(date +%s)
            freebayes -f "\$NF_REF" -p "\$NF_PLOIDY" \$NF_ARGS -L "\$NF_BAM_LIST" --region "\$region" > "\$chunk_vcf" 2> "\$stderr_log"
            status=\$?
            end_epoch=\$(date +%s)
            duration_seconds=\$((end_epoch - start_epoch))
            if [ "\$NF_DEBUG" = "true" ]; then
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                    "\$chunk_id" "\$region" "\$status" "\$start_epoch" "\$end_epoch" "\$duration_seconds" "\$chunk_vcf" "\$stderr_log" > "\$metric_file"
            fi
            exit "\$status"
        ' sh
    xargs_status=\$?
    set -e

    if [ "${debugEnabled}" = 'true' ]; then
        find ${diagnosticsDir}/metrics -type f -name '*.tsv' | LC_ALL=C sort > metric_files.list
        [ -s metric_files.list ] || { echo 'No Freebayes diagnostic metrics were produced' >&2; exit 1; }

        printf 'chunk_id\tregion\texit_status\tstart_epoch\tend_epoch\tduration_seconds\tvcf_path\tstderr_log\n' > ${diagnosticsDir}/region_runtime.tsv
        xargs cat < metric_files.list >> ${diagnosticsDir}/region_runtime.tsv

        printf 'chunk_id\tregion\texit_status\tstart_epoch\tend_epoch\tduration_seconds\tvcf_path\tstderr_log\n' > ${diagnosticsDir}/slowest_regions.tsv
        tail -n +2 ${diagnosticsDir}/region_runtime.tsv | LC_ALL=C sort -t "\$(printf '\t')" -k6,6nr | awk 'NR <= 10' >> ${diagnosticsDir}/slowest_regions.tsv
    fi

    if [ "\$xargs_status" -ne 0 ]; then
        echo 'One or more Freebayes chunk calls failed; see freebayes diagnostics for details' >&2
        exit "\$xargs_status"
    fi

    find chunks -type f -name '*.vcf' | LC_ALL=C sort > chunk_vcfs.list
    [ -s chunk_vcfs.list ] || { echo 'No Freebayes chunk outputs were produced' >&2; exit 1; }

    set +e
    set +o pipefail
    xargs cat < chunk_vcfs.list | vcffirstheader | vcfstreamsort -w 1000 | vcfuniq > merged.vcf
    merge_status=\$?
    set -o pipefail
    set -e
    if [ "\$merge_status" -ne 0 ]; then
        exit "\$merge_status"
    fi

    bgzip -c merged.vcf > ${meta.id}.vcf.gz
    tabix -p vcf ${meta.id}.vcf.gz
    rm -f merged.vcf chunk_vcfs.list
    rm -rf chunks
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
    def threads = Math.max(1, (task.cpus ?: 1) as Integer)
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