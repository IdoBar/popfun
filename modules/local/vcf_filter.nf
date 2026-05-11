process VCF_FILTER {
    tag "$meta.id"
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input: tuple val(meta), path(vcf)
    output:
        tuple val(meta), path("${meta.id}.Q${params.filter_qual}.poly.vcf.gz"), emit: filtered_vcf
        tuple val(meta), path("${meta.id}.Q${params.filter_qual}.poly.vcf.gz.tbi"), emit: filtered_vcf_tbi
        tuple val(meta), path("${meta.id}.snps.Q${params.filter_qual}.poly.vcf.gz"), emit: snps_vcf
        tuple val(meta), path("${meta.id}.indels.Q${params.filter_qual}.poly.vcf.gz"), emit: indels_vcf
    def gt_filter_expr = params.mask_hetero ? "GT=='het' || " : ""
    script:
    """
    bcftools filter -S . -e "${gt_filter_expr}FMT/DP<${params.filter_ind_dp}" "$vcf" | \
    bcftools +fill-tags -- -t AN,AC,AF,F_MISSING,'DP:1=int(sum(FORMAT/DP))' | \
    bcftools view -i "QUAL>=${params.filter_qual} && INFO/DP>=${params.filter_min_dp} && INFO/DP<=${params.filter_max_dp} && COUNT(GT='ref')>=1 && COUNT(GT='alt')>=1" \
    -O z -o "${meta.id}.Q${params.filter_qual}.poly.vcf.gz"
    
    bcftools index -t "${meta.id}.Q${params.filter_qual}.poly.vcf.gz"

    bcftools view -v snps -i "QUAL>=${params.filter_qual}" \
    "${meta.id}.Q${params.filter_qual}.poly.vcf.gz" | \
    bcftools +fill-tags -O z -o "${meta.id}.snps.Q${params.filter_qual}.poly.vcf.gz" \
        -- -t AN,AC,AF,'DP:1=int(sum(FORMAT/DP))'

    bcftools index -t "${meta.id}.snps.Q${params.filter_qual}.poly.vcf.gz"

    bcftools view -v indels -i "QUAL>=${params.filter_qual}" \
    "${meta.id}.Q${params.filter_qual}.poly.vcf.gz" | \
    bcftools +fill-tags -O z -o "${meta.id}.indels.Q${params.filter_qual}.poly.vcf.gz" \
        -- -t AN,AC,AF,'DP:1=int(sum(FORMAT/DP))'

    bcftools index -t "${meta.id}.indels.Q${params.filter_qual}.poly.vcf.gz"
    """
}
