process VCF_FILTER {
    tag "$meta.id"
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input: tuple val(meta), path(vcf)
    output:
        tuple val(meta), path("${meta.id == 'population' ? 'fb_pop' : (meta.id == 'merged' ? 'fb_merged' : meta.id)}.Q${params.filter_qual}.poly.vcf.gz"), emit: filtered_vcf
        tuple val(meta), path("${meta.id == 'population' ? 'fb_pop' : (meta.id == 'merged' ? 'fb_merged' : meta.id)}.Q${params.filter_qual}.poly.vcf.gz.tbi"), emit: filtered_vcf_tbi
        tuple val(meta), path("${meta.id == 'population' ? 'fb_pop' : (meta.id == 'merged' ? 'fb_merged' : meta.id)}.snps.Q${params.filter_qual}.poly.vcf.gz"), emit: snps_vcf
        tuple val(meta), path("${meta.id == 'population' ? 'fb_pop' : (meta.id == 'merged' ? 'fb_merged' : meta.id)}.indels.Q${params.filter_qual}.poly.vcf.gz"), emit: indels_vcf
    def gt_filter_expr = params.mask_hetero ? "GT=='het' || " : ""
    script:
    """
    canonical_id="${meta.id}"
    if [[ "\$canonical_id" == "population" ]]; then
        canonical_id="fb_pop"
    elif [[ "\$canonical_id" == "merged" ]]; then
        canonical_id="fb_merged"
    fi

    bcftools filter -S . -e "${gt_filter_expr}FMT/DP<${params.filter_ind_dp}" "$vcf" | \
    bcftools +fill-tags -- -t AN,AC,AF,F_MISSING,'DP:1=int(sum(FORMAT/DP))' | \
    bcftools view -i "QUAL>=${params.filter_qual} && INFO/DP>=${params.filter_min_dp} && INFO/DP<=${params.filter_max_dp} && COUNT(GT='ref')>=1 && COUNT(GT='alt')>=1" \
    -O z -o "\$canonical_id.Q${params.filter_qual}.poly.vcf.gz"
    
    bcftools index -t "\$canonical_id.Q${params.filter_qual}.poly.vcf.gz"

    bcftools view -v snps -i "QUAL>=${params.filter_qual}" \
    "\$canonical_id.Q${params.filter_qual}.poly.vcf.gz" | \
    bcftools +fill-tags -O z -o "\$canonical_id.snps.Q${params.filter_qual}.poly.vcf.gz" \
        -- -t AN,AC,AF,'DP:1=int(sum(FORMAT/DP))'

    bcftools index -t "\$canonical_id.snps.Q${params.filter_qual}.poly.vcf.gz"

    bcftools view -v indels -i "QUAL>=${params.filter_qual}" \
    "\$canonical_id.Q${params.filter_qual}.poly.vcf.gz" | \
    bcftools +fill-tags -O z -o "\$canonical_id.indels.Q${params.filter_qual}.poly.vcf.gz" \
        -- -t AN,AC,AF,'DP:1=int(sum(FORMAT/DP))'

    bcftools index -t "\$canonical_id.indels.Q${params.filter_qual}.poly.vcf.gz"
    """
}
