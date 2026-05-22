process BCFTOOLS_MERGE {
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input:
        path vcfs
        path tbis
    output: path "fb_merged.vcf.gz", emit: vcf
    script:
    """
    echo \"${vcfs.join('\n')}\" > vcf_list.txt
    # find -L . -type f -name '*.bam' | LC_ALL=C sort > vcf_list.txt
    # printf '%s\\n' "$vcfs" > vcf_list.txt
    bcftools merge --force-samples -l vcf_list.txt -O z -o fb_merged.vcf.gz
    """
}

process BCFTOOLS_CONCAT {
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input:
        tuple path(vcfs), path(tbis)
    output:
        path "fb_pop.vcf.gz", emit: vcf
        path "fb_pop.vcf.gz.tbi", emit: tbi
    script:
    """
    echo \"${vcfs.join('\n')}\" > vcf_list.txt
    # find -L . -type f -name '*.bam' | LC_ALL=C sort > vcf_list.txt
    bcftools concat -f vcf_list.txt -Oz -o fb_pop.vcf.gz
    tabix -p vcf fb_pop.vcf.gz
    """
}

process BCFTOOLS_STATS {
    tag "$meta.id"
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input: tuple val(meta), path(vcf)
    output: path "${meta.id}.vcf.stats", emit: stats 
    script:
    """
    bcftools stats "$vcf" > "${meta.id}.vcf.stats"
    """
}

process VCF_ENSEMBLE_COMBINE {
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input:
        path vcf_gatk
        path tbi_gatk
        path vcf_fb
        path tbi_fb
    output:
        tuple val('ensemble'), path('ensemble.vcf.gz'), path('ensemble.vcf.gz.tbi'), emit: vcf
    script:
    """
    set -euo pipefail

    bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%QUAL\\n' "$vcf_gatk" | sort -k1,1 -k2,2n -k3,3 -k4,4 > gatk.tsv
    bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%QUAL\\n' "$vcf_fb" | sort -k1,1 -k2,2n -k3,3 -k4,4 > freebayes.tsv

    awk 'BEGIN { FS=OFS="\\t" }
        NR==FNR {
            key = \$1":"\$2":"\$3":"\$4
            gatk_qual[key] = \$5
            next
        }
        {
            key = \$1":"\$2":"\$3":"\$4
            if (key in gatk_qual) {
                print key, gatk_qual[key], \$5
            }
        }
    ' gatk.tsv freebayes.tsv > shared_sites.tsv

    awk 'BEGIN{FS=OFS="\\t"} {
        split(\$1, parts, ":")
        qual1 = (\$2 == "." ? -1 : \$2 + 0)
        qual2 = (\$3 == "." ? -1 : \$3 + 0)
        source = (qual1 >= qual2) ? "gatk" : "freebayes"
        print parts[1], parts[2], parts[3], parts[4], source
    }' shared_sites.tsv > winners.tsv

    awk 'BEGIN{FS=OFS="\\t"} \$5 == "gatk" {print \$1, \$2, \$3, \$4}' winners.tsv > gatk.keep.tsv
    awk 'BEGIN{FS=OFS="\\t"} \$5 == "freebayes" {print \$1, \$2, \$3, \$4}' winners.tsv > freebayes.keep.tsv

    {
        {
            bcftools view -h "$vcf_gatk" | grep -v '^#CHROM'
            bcftools view -h "$vcf_fb" | awk '!/^##FORMAT=<ID=GQ,/' | grep -v '^#CHROM'
        } | awk '!seen[\$0]++'
        printf '##INFO=<ID=CALLERS,Number=.,Type=String,Description="Callers reporting this variant">\\n'
        printf '##INFO=<ID=NUM_CALLERS,Number=1,Type=Integer,Description="Number of callers supporting this variant">\\n'
        bcftools view -h "$vcf_gatk" | awk '/^#CHROM/'
    } > ensemble.header.vcf

    bcftools view -H "$vcf_gatk" | awk 'BEGIN{FS=OFS="\\t"}
        NR==FNR { keep[\$1 FS \$2 FS \$3 FS \$4] = 1; next }
        {
            key = \$1 FS \$2 FS \$4 FS \$5
            if (!keep[key]) next
            info = (\$8 == ".") ? "CALLERS=gatk,freebayes;NUM_CALLERS=2" : \$8 ";CALLERS=gatk,freebayes;NUM_CALLERS=2"
            \$8 = info
            print
        }
    ' gatk.keep.tsv - > gatk.selected.vcf

    bcftools view -H "$vcf_fb" | awk 'BEGIN{FS=OFS="\\t"}
        function normalize_gq(format_field, sample_field,    format_parts, sample_parts, gq_idx, idx, rebuilt) {
            gq_idx = 0
            split(format_field, format_parts, ":")
            for (idx = 1; idx <= length(format_parts); idx++) {
                if (format_parts[idx] == "GQ") {
                    gq_idx = idx
                    break
                }
            }
            if (!gq_idx) {
                return sample_field
            }

            split(sample_field, sample_parts, ":")
            if ((gq_idx in sample_parts) && sample_parts[gq_idx] != "." && sample_parts[gq_idx] != "") {
                sample_parts[gq_idx] = sprintf("%d", sample_parts[gq_idx] + 0)
            }

            rebuilt = sample_parts[1]
            for (idx = 2; idx <= length(sample_parts); idx++) {
                rebuilt = rebuilt ":" sample_parts[idx]
            }
            return rebuilt
        }
        NR==FNR { keep[\$1 FS \$2 FS \$3 FS \$4] = 1; next }
        {
            key = \$1 FS \$2 FS \$4 FS \$5
            if (!keep[key]) next
            info = (\$8 == ".") ? "CALLERS=gatk,freebayes;NUM_CALLERS=2" : \$8 ";CALLERS=gatk,freebayes;NUM_CALLERS=2"
            \$8 = info
            for (sample_idx = 10; sample_idx <= NF; sample_idx++) {
                \$sample_idx = normalize_gq(\$9, \$sample_idx)
            }
            print
        }
    ' freebayes.keep.tsv - > freebayes.selected.vcf

    cat ensemble.header.vcf gatk.selected.vcf freebayes.selected.vcf | bgzip -c > ensemble.unsorted.vcf.gz
    bcftools sort -O z -o ensemble.vcf.gz ensemble.unsorted.vcf.gz
    tabix -f -p vcf ensemble.vcf.gz
    """
}

process VCF_ENSEMBLE_NORMALIZE {
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input:
        path vcf_gatk
        path tbi_gatk
        path vcf_fb
        path tbi_fb
        path ref
    output:
        path 'gatk.norm.vcf.gz', emit: gatk_vcf
        path 'gatk.norm.vcf.gz.tbi', emit: gatk_tbi
        path 'freebayes.norm.vcf.gz', emit: freebayes_vcf
        path 'freebayes.norm.vcf.gz.tbi', emit: freebayes_tbi
    script:
    """
    set -euo pipefail

    bcftools norm -f "$ref" -m -any -O z -o gatk.norm.vcf.gz "$vcf_gatk"
    tabix -f -p vcf gatk.norm.vcf.gz

    bcftools norm -f "$ref" -m -any -O z -o freebayes.norm.vcf.gz "$vcf_fb"
    tabix -f -p vcf freebayes.norm.vcf.gz
    """
}

process VCF_ENSEMBLE_MATCH_RTG {
    label 'sc_medium'
    conda "bioconda::rtg-tools=3.13"
    container 'quay.io/biocontainers/rtg-tools:3.13--hdfd78af_0'
    input:
        path gatk_norm_vcf
        path gatk_norm_tbi
        path freebayes_norm_vcf
        path freebayes_norm_tbi
        path ref
    output:
        path 'gatk.keep.tsv', emit: gatk_keep
        path 'freebayes.keep.tsv', emit: freebayes_keep
    script:
    """
    set -euo pipefail

    shared_sample="\$(
        comm -12 \
            <(gzip -dc "$gatk_norm_vcf" | awk 'BEGIN{FS="\\t"} /^#CHROM/ {for (i=10; i<=NF; i++) print \$i; exit}' | LC_ALL=C sort -u) \
            <(gzip -dc "$freebayes_norm_vcf" | awk 'BEGIN{FS="\\t"} /^#CHROM/ {for (i=10; i<=NF; i++) print \$i; exit}' | LC_ALL=C sort -u) \
        | head -n 1
    )"
    if [[ -z "\$shared_sample" ]]; then
        echo "Error: no shared sample between baseline and calls VCF headers for rtg vcfeval" >&2
        exit 1
    fi

    # Check if VCF records and reference share contig names.
    # If not, RTG vcfeval cannot evaluate and we fall back to direct normalized VCF matching.
    awk '/^>/ {print substr(\$1, 2)}' "$ref" | LC_ALL=C sort -u > ref.contigs
    gzip -dc "$gatk_norm_vcf" | awk '!/^#/ {print \$1}' | LC_ALL=C sort -u > gatk.contigs
    gzip -dc "$freebayes_norm_vcf" | awk '!/^#/ {print \$1}' | LC_ALL=C sort -u > freebayes.contigs

    ref_gatk_overlap=\$(comm -12 ref.contigs gatk.contigs | head -n 1 || true)
    ref_freebayes_overlap=\$(comm -12 ref.contigs freebayes.contigs | head -n 1 || true)

    use_rtg=true
    if [[ -z "\$ref_gatk_overlap" || -z "\$ref_freebayes_overlap" ]]; then
        echo "Warning: No shared contig names between reference and one or both normalized VCFs; falling back to direct VCF overlap matching." >&2
        use_rtg=false
    fi

    if [[ "\$use_rtg" == "true" ]]; then
        rtg format -o ref.sdf "$ref"
        if ! rtg vcfeval \
            --baseline "$gatk_norm_vcf" \
            --calls "$freebayes_norm_vcf" \
            --template ref.sdf \
            --output vcfeval_out \
            --all-records \
            --squash-ploidy \
            --sample "\$shared_sample" 2> rtg.stderr; then
            if grep -qi 'no sequence names in common' rtg.stderr; then
                echo "Warning: RTG vcfeval failed due to contig-name mismatch; falling back to direct VCF overlap matching." >&2
                use_rtg=false
            else
                cat rtg.stderr >&2
                exit 1
            fi
        fi
    fi

    if [[ "\$use_rtg" == "true" ]]; then
        gzip -dc vcfeval_out/tp-baseline.vcf.gz | awk 'BEGIN{FS=OFS="\t"} !/^#/ { print \$1, \$2, \$4, \$5, \$6 }' | sort -k1,1 -k2,2n -k3,3 -k4,4 > gatk.tsv
        gzip -dc vcfeval_out/tp.vcf.gz | awk 'BEGIN{FS=OFS="\t"} !/^#/ { print \$1, \$2, \$4, \$5, \$6 }' | sort -k1,1 -k2,2n -k3,3 -k4,4 > freebayes.tsv
    else
        gzip -dc "$gatk_norm_vcf" | awk 'BEGIN{FS=OFS="\t"} !/^#/ { print \$1, \$2, \$4, \$5, \$6 }' | sort -k1,1 -k2,2n -k3,3 -k4,4 > gatk.tsv
        gzip -dc "$freebayes_norm_vcf" | awk 'BEGIN{FS=OFS="\t"} !/^#/ { print \$1, \$2, \$4, \$5, \$6 }' | sort -k1,1 -k2,2n -k3,3 -k4,4 > freebayes.tsv
    fi

    awk 'BEGIN { FS=OFS="\t" }
        NR==FNR {
            key = \$1":"\$2":"\$3":"\$4
            gatk_qual[key] = \$5
            next
        }
        {
            key = \$1":"\$2":"\$3":"\$4
            if (key in gatk_qual) {
                print key, gatk_qual[key], \$5
            }
        }
    ' gatk.tsv freebayes.tsv > shared_sites.tsv

    awk 'BEGIN{FS=OFS="\t"} {
        split(\$1, parts, ":")
        qual1 = (\$2 == "." ? -1 : \$2 + 0)
        qual2 = (\$3 == "." ? -1 : \$3 + 0)
        source = (qual1 >= qual2) ? "gatk" : "freebayes"
        print parts[1], parts[2], parts[3], parts[4], source
    }' shared_sites.tsv > winners.tsv

    awk 'BEGIN{FS=OFS="\t"} \$5 == "gatk" {print \$1, \$2, \$3, \$4}' winners.tsv > gatk.keep.tsv
    awk 'BEGIN{FS=OFS="\t"} \$5 == "freebayes" {print \$1, \$2, \$3, \$4}' winners.tsv > freebayes.keep.tsv
    """
}

process VCF_ENSEMBLE_ASSEMBLE {
    label 'sc_medium'
    conda "bioconda::bcftools=1.23.1"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'
    input:
        path gatk_norm_vcf
        path gatk_norm_tbi
        path freebayes_norm_vcf
        path freebayes_norm_tbi
        path gatk_keep
        path freebayes_keep
    output:
        tuple val('ensemble'), path('ensemble.vcf.gz'), path('ensemble.vcf.gz.tbi'), emit: vcf
    script:
    """
    set -euo pipefail

    {
        {
            bcftools view -h "$gatk_norm_vcf" | grep -v '^#CHROM'
            bcftools view -h "$freebayes_norm_vcf" | awk '!/^##FORMAT=<ID=GQ,/' | grep -v '^#CHROM'
        } | awk '!seen[\$0]++'
        printf '##INFO=<ID=CALLERS,Number=.,Type=String,Description="Callers reporting this variant">\n'
        printf '##INFO=<ID=NUM_CALLERS,Number=1,Type=Integer,Description="Number of callers supporting this variant">\n'
        bcftools view -h "$gatk_norm_vcf" | awk '/^#CHROM/'
    } > ensemble.header.vcf

    bcftools view -H "$gatk_norm_vcf" | awk 'BEGIN{FS=OFS="\t"}
        NR==FNR { keep[\$1 FS \$2 FS \$3 FS \$4] = 1; next }
        {
            key = \$1 FS \$2 FS \$4 FS \$5
            if (!keep[key]) next
            info = (\$8 == ".") ? "CALLERS=gatk,freebayes;NUM_CALLERS=2" : \$8 ";CALLERS=gatk,freebayes;NUM_CALLERS=2"
            \$8 = info
            print
        }
    ' "$gatk_keep" - > gatk.selected.vcf

    bcftools view -H "$freebayes_norm_vcf" | awk 'BEGIN{FS=OFS="\t"}
        function normalize_gq(format_field, sample_field,    format_parts, sample_parts, gq_idx, idx, rebuilt) {
            gq_idx = 0
            split(format_field, format_parts, ":")
            for (idx = 1; idx <= length(format_parts); idx++) {
                if (format_parts[idx] == "GQ") {
                    gq_idx = idx
                    break
                }
            }
            if (!gq_idx) {
                return sample_field
            }

            split(sample_field, sample_parts, ":")
            if ((gq_idx in sample_parts) && sample_parts[gq_idx] != "." && sample_parts[gq_idx] != "") {
                sample_parts[gq_idx] = sprintf("%d", sample_parts[gq_idx] + 0)
            }

            rebuilt = sample_parts[1]
            for (idx = 2; idx <= length(sample_parts); idx++) {
                rebuilt = rebuilt ":" sample_parts[idx]
            }
            return rebuilt
        }
        NR==FNR { keep[\$1 FS \$2 FS \$3 FS \$4] = 1; next }
        {
            key = \$1 FS \$2 FS \$4 FS \$5
            if (!keep[key]) next
            info = (\$8 == ".") ? "CALLERS=gatk,freebayes;NUM_CALLERS=2" : \$8 ";CALLERS=gatk,freebayes;NUM_CALLERS=2"
            \$8 = info
            for (sample_idx = 10; sample_idx <= NF; sample_idx++) {
                \$sample_idx = normalize_gq(\$9, \$sample_idx)
            }
            print
        }
    ' "$freebayes_keep" - > freebayes.selected.vcf

    cat ensemble.header.vcf gatk.selected.vcf freebayes.selected.vcf | bgzip -c > ensemble.unsorted.vcf.gz
    bcftools sort -O z -o ensemble.vcf.gz ensemble.unsorted.vcf.gz
    tabix -f -p vcf ensemble.vcf.gz
    """
}
