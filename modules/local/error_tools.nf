// Save as: modules/local/error_tools.nf

process MARK_DUPLICATES_LIB {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'sc_medium'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.dedup.bam"), path("*.dedup.bai"), emit: dedup_bam
    path "*.metrics.txt", emit: metrics

    script:
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    gatk MarkDuplicates \\
        -I $bam \\
        -O ${unitId}.dedup.bam \\
        -M ${unitId}.metrics.txt \\
        --CREATE_INDEX true \\
        --READ_NAME_REGEX null
    """
}

process MARK_DUPLICATES_LIB_BAMSORMADUP {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::biobambam=2.0.185"
    container 'quay.io/biocontainers/biobambam:2.0.185--h85de650_1'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.dedup.bam"), path("*.dedup.bai"), emit: dedup_bam
    path "*.metrics.txt", emit: metrics

    script:
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    bamcollate2 inputformat=bam outputformat=bam level=1 < $bam | \
    bamsormadup SO=coordinate inputformat=bam level=1 threads=${task.cpus} M=${unitId}.metrics.txt > ${unitId}.dedup.bam
    bamindex < ${unitId}.dedup.bam > ${unitId}.dedup.bai
    """
}

process MARK_DUPLICATES_LIB_SAMBAMBA {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::sambamba=1.0.1"
    container 'quay.io/biocontainers/sambamba:1.0.1--h6f6fda4_1'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.dedup.bam"), path("*.dedup.bai"), emit: dedup_bam
    path "*.sambamba_markdup.log", emit: metrics

    script:
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    sambamba markdup -t ${task.cpus} $bam ${unitId}.dedup.bam 2> ${unitId}.sambamba_markdup.log
    sambamba index -t ${task.cpus} ${unitId}.dedup.bam ${unitId}.dedup.bai
    """
}

process MARK_DUPLICATES_LIB_FASTDUP {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::fastdup=1.0.0 bioconda::samtools=1.23.1"
    container 'ghcr.io/idobar/fastdup:latest'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.dedup.bam"), path("*.dedup.bai"), emit: dedup_bam
    path "*.metrics.txt", emit: metrics

    script:
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    fastdup --input $bam --output ${unitId}.dedup.bam --metrics ${unitId}.metrics.txt --num-threads ${task.cpus}
    samtools index -@ ${task.cpus} ${unitId}.dedup.bam ${unitId}.dedup.bai
    """
}

process GATK_CALL_LIB {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'sc_medium'
    conda "bioconda::gatk4=4.6.2.0"
    container 'broadinstitute/gatk:4.6.2.0'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_idx 
    path ref_dict 

    output:
    tuple val(meta), path("*.vcf.gz"), path("*.vcf.gz.tbi"), emit: vcf

    script:
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    gatk --java-options "-Xmx${task.memory.toGiga()}g" HaplotypeCaller \\
        -R $ref \\
        -I $bam \\
        -O ${unitId}.vcf.gz \\
        -ploidy ${params.ploidy}
    """
}

process FREEBAYES_CALL_LIB {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::freebayes=1.3.10"
    container 'quay.io/biocontainers/freebayes:1.3.10--hbefcdb2_0'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_idx

    output:
    tuple val(meta), path("*.vcf.gz"), path("*.vcf.gz.tbi"), emit: vcf

    script:
    def args = task.ext.args ?: ''
    def maxInnerThreads = (params.caller_inner_threads ?: 8) as Integer
    def threads = Math.max(1, Math.min((task.cpus ?: 1) as Integer, maxInnerThreads))
    def unitId = meta.unit_id ?: meta.library ?: meta.id
    """
    awk '{ print \$1 ":1-" \$2 }' $ref_idx > chromosome_regions.txt

    freebayes-parallel chromosome_regions.txt ${threads} -f $ref -p ${params.ploidy} $args $bam | bgzip -c > ${unitId}.vcf.gz
    tabix -p vcf ${unitId}.vcf.gz
    """
}

process VCF_MULTI_COMPARE {
    tag "$meta.id"
    label 'sc_small'
    conda "conda-forge::python=3.9 conda-forge::pandas=1.4.2 bioconda::pysam=0.19.1"
    container 'quay.io/biocontainers/mulled-v2-629aec3ba267b06a1efc3ec454c0f09e134f6ee2:3b083bb5eae6e491b8579589b070fa29afbea2a1-0'

    input:
    tuple val(meta), val(compare_label), path(vcfs), path(indexes)
    path compare_script

    output:
    path "${meta.id}_${compare_label}_discordance.csv", emit: report

    script:
    def vcf_args = vcfs.collect { "'${it}'" }.join(' ')
    """
    python $compare_script \\
        --vcfs ${vcf_args} \\
        --sample ${meta.id} \\
        --out ${meta.id}_${compare_label}_discordance.csv
    """
}

process VCF_DISCORDANCE_MQC {
    label 'sc_small'
    conda "conda-forge::python=3.9 conda-forge::pandas=1.4.2"
    container 'quay.io/biocontainers/mulled-v2-629aec3ba267b06a1efc3ec454c0f09e134f6ee2:3b083bb5eae6e491b8579589b070fa29afbea2a1-0'

    input:
    path discordance_csvs

    output:
    path "hapfun_discordance_rate_mqc.csv", emit: mqc_rate_csv
    path "hapfun_discordance_metrics_mqc.csv", emit: mqc_metrics_csv

    script:
    """
    python - << 'PY'
from pathlib import Path

import pandas as pd

sample_values = {}
metric_cols = ['shared_sites', 'concordant', 'discordant', 'discordance_rate']

for p in Path('.').glob('*_discordance.csv'):
    stem = p.name[:-len('_discordance.csv')]
    if '_' not in stem:
        continue

    sample_id, phase = stem.rsplit('_', 1)
    if phase not in ('raw', 'filtered'):
        continue

    df = pd.read_csv(p)

    phase_stats = {}
    for col in metric_cols:
        if col in df.columns and len(df) > 0:
            vals = pd.to_numeric(df[col], errors='coerce').dropna()
            phase_stats[col] = float(vals.mean()) if len(vals) > 0 else 0.0
        else:
            phase_stats[col] = 0.0

    sample_values.setdefault(sample_id, {})[phase] = phase_stats

for sample_id in sample_values:
    sample_values[sample_id].setdefault('raw', {col: 0.0 for col in metric_cols})
    sample_values[sample_id].setdefault('filtered', {col: 0.0 for col in metric_cols})

rate_header = '''# id: 'hapfun_discordance_rate'
# section_name: 'Library Discordance Before vs After Filtering'
# description: 'Mean pairwise genotype discordance rate per sample, comparing raw and filtered variant calls.'
# plot_type: 'bargraph'
# pconfig:
#   id: 'hapfun_discordance_rate_plot'
#   title: 'Discordance Before vs After Filtering'
#   ylab: 'Discordance rate'
#   xlab: 'Sample'
'''

rate_rows = ["Sample,Raw,Filtered"]
for sample_id, vals in sorted(sample_values.items()):
    rate_rows.append(
        f"{sample_id},{round(vals['raw']['discordance_rate'], 6)},{round(vals['filtered']['discordance_rate'], 6)}"
    )

metrics_header = '''# id: 'hapfun_discordance_metrics'
# section_name: 'Library Discordance Metrics (Raw vs Filtered)'
# description: 'Mean pairwise shared sites, concordant sites, discordant sites, and discordance rate per sample for raw and filtered calls.'
# plot_type: 'table'
# pconfig:
#   id: 'hapfun_discordance_metrics_table'
#   title: 'Library Discordance Metrics (Raw vs Filtered)'
'''

metrics_rows = [
    "Sample,raw_shared_sites,raw_concordant,raw_discordant,raw_discordance_rate,filtered_shared_sites,filtered_concordant,filtered_discordant,filtered_discordance_rate"
]
for sample_id, vals in sorted(sample_values.items()):
    metrics_rows.append(
        f"{sample_id},"
        f"{round(vals['raw']['shared_sites'], 6)},{round(vals['raw']['concordant'], 6)},{round(vals['raw']['discordant'], 6)},{round(vals['raw']['discordance_rate'], 6)},"
        f"{round(vals['filtered']['shared_sites'], 6)},{round(vals['filtered']['concordant'], 6)},{round(vals['filtered']['discordant'], 6)},{round(vals['filtered']['discordance_rate'], 6)}"
    )

nl = chr(10)
with open('hapfun_discordance_rate_mqc.csv', 'w') as fh:
    fh.write(rate_header)
    fh.write(nl.join(rate_rows) + nl)

with open('hapfun_discordance_metrics_mqc.csv', 'w') as fh:
    fh.write(metrics_header)
    fh.write(nl.join(metrics_rows) + nl)
PY
    """
}