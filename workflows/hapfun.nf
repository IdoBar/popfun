include { FASTP; FASTQC; TRIMMOMATIC } from '../modules/local/qc_tools'
include { BWA_ALIGN; BOWTIE2_ALIGN; SAMTOOLS_SORT_ALIGN } from '../modules/local/aligners'
include { DECOMPRESS_FASTA; SAMTOOLS_FAIDX; GATK_DICTIONARY; BWA_INDEX; BOWTIE2_INDEX } from '../modules/local/reference_prep'
include { GFF_TO_BED } from '../modules/local/annotation_prep'
include { FREEBAYES_SPLIT_REGIONS } from '../modules/local/genome_regions'
include { SAMTOOLS_MERGE; MARK_DUPLICATES; MARK_DUPLICATES_BAMSORMADUP; MARK_DUPLICATES_SAMBAMBA; MARK_DUPLICATES_FASTDUP; QUALIMAP } from '../modules/local/bam_tools'
include { FREEBAYES_POPULATION; FREEBAYES; FREEBAYES_GVCF; GATK_HAPLOTYPECALLER; GATK_COMBINEGVCFS; GATK_GENOTYPEGVCFS; GLNEXUS_COHORT } from '../modules/local/variant_callers'
include { BCFTOOLS_MERGE; BCFTOOLS_CONCAT } from '../modules/local/vcf_tools'
include { GENERATE_SOFTWARE_VERSIONS_MQC; MULTIQC } from '../modules/local/multiqc'
include { POPGEN_ANALYSES } from '../modules/local/popgen'
include { MARK_DUPLICATES_LIB; MARK_DUPLICATES_LIB_BAMSORMADUP; MARK_DUPLICATES_LIB_SAMBAMBA; MARK_DUPLICATES_LIB_FASTDUP; GATK_CALL_LIB; FREEBAYES_CALL_LIB; VCF_MULTI_COMPARE as VCF_MULTI_COMPARE_RAW; VCF_MULTI_COMPARE as VCF_MULTI_COMPARE_FILTERED; VCF_DISCORDANCE_MQC } from '../modules/local/error_tools'
include { VCF_FILTER as VCF_FILTER_LIB; VCF_FILTER as VCF_FILTER_FINAL } from '../modules/local/vcf_filter'
include { BCFTOOLS_STATS as BCFTOOLS_STATS_RAW; BCFTOOLS_STATS as BCFTOOLS_STATS_FILTERED } from '../modules/local/vcf_tools'

workflow HAPFUN {
    ch_multiqc_reports = Channel.empty()

    def step_order = [qc: 1, alignment: 2, call: 3, filter: 4, multiqc: 5]
    def valid_start_steps = ['qc', 'alignment']
    def valid_stop_steps = ['qc', 'alignment', 'call', 'filter', 'multiqc']
    def valid_markdup_tools = ['gatk', 'bamsormadup', 'sambamba', 'fastdup']
    def valid_gvcf_joint_callers = ['gatk', 'glnexus']

    if (!valid_start_steps.contains(params.start_step)) {
        error "Invalid --start_step '${params.start_step}'. Supported values: ${valid_start_steps.join(', ')}"
    }
    if (!valid_stop_steps.contains(params.stop_at)) {
        error "Invalid --stop_at '${params.stop_at}'. Supported values: ${valid_stop_steps.join(', ')}"
    }
    if (!valid_markdup_tools.contains(params.markdup_tool)) {
        error "Invalid --markdup_tool '${params.markdup_tool}'. Supported values: ${valid_markdup_tools.join(', ')}"
    }
    if (!valid_gvcf_joint_callers.contains(params.gvcf_joint_caller)) {
        error "Invalid --gvcf_joint_caller '${params.gvcf_joint_caller}'. Supported values: ${valid_gvcf_joint_callers.join(', ')}"
    }
    if (params.caller == 'freebayes' && params.gvcf_joint_caller == 'glnexus' && params.freebayes_mode == 'population') {
        error "--gvcf_joint_caller glnexus with --caller freebayes requires --freebayes_mode individual so per-sample gVCFs can be generated"
    }
    if ((params.freebayes_chunk_size as Integer) < 1) {
        error "Invalid --freebayes_chunk_size '${params.freebayes_chunk_size}'. Value must be >= 1"
    }
    if (step_order[params.start_step] > step_order[params.stop_at]) {
        error "Invalid step window: --start_step '${params.start_step}' occurs after --stop_at '${params.stop_at}'"
    }
    
    // 1. INPUT PARSING
    ch_input = Channel.fromPath(params.input).splitCsv(header:true).map { row ->
        def norm = row.collectEntries { key, value ->
            def normKey = key == null ? null : key.toString().trim().toLowerCase()
            def normValue = value == null ? '' : value.toString().trim()
            [(normKey): normValue]
        }.findAll { key, value -> key != null }

        def sampleId = norm.sample
        def libraryId = norm.library
        def fq1 = norm.fq1
        def fq2 = norm.fq2
        def rowPreview = row.collect { key, value -> "${key}=${value}" }.join(', ')

        if (!sampleId) {
            error "Samplesheet row is missing required 'sample' value: ${rowPreview}"
        }
        if (!libraryId) {
            error "Samplesheet row is missing required 'library' value: ${rowPreview}"
        }
        if (!fq1 || !fq2) {
            error "Samplesheet row is missing required 'fq1'/'fq2' value: ${rowPreview}"
        }

        def meta = [ id: sampleId, library: libraryId, unit_id: libraryId, pop: (norm.pop ?: 'NA'), single_end: false ]
        tuple(meta, file(fq1), file(fq2))
    }
    ch_samplesheet = Channel.value(file(params.input))
    
    def ref_file = file(params.ref)
    def ref_is_gz = ref_file.name.toLowerCase().endsWith('.gz')
    def ch_ref
    def ref_prefix

    if (ref_is_gz) {
        DECOMPRESS_FASTA(ref_file)
        ch_ref = DECOMPRESS_FASTA.out.fasta
        ref_prefix = 'reference.decompressed.fa'
    } else {
        ch_ref = Channel.value(ref_file)
        ref_prefix = ref_file.name
    }
    
    // Stage MultiQC config and logo together so the relative logo path in the YAML resolves
    ch_multiqc_config = file(params.multiqc_config)
    ch_multiqc_logo   = file("$projectDir/assets/hapfun.png")
    ch_vcf_compare_script = Channel.value(file("$projectDir/bin/vcf_multi_compare.py"))
    ch_popgen_script = Channel.value(file("$projectDir/bin/popgen_analyses.py"))

    // --- STEP 1: QC ---
    if (params.start_step == 'qc') {
        if (params.trimmer == 'fastp') {
            FASTP(ch_input)
            ch_reads = FASTP.out.trimmed_reads
            ch_multiqc_reports = ch_multiqc_reports.mix(FASTP.out.json)
        } 
        else if (params.trimmer == 'trimmomatic') {
            FASTQC(ch_input)
            ch_multiqc_reports = ch_multiqc_reports.mix(FASTQC.out.results)

            TRIMMOMATIC(ch_input)
            ch_reads = TRIMMOMATIC.out.trimmed_reads
            ch_multiqc_reports = ch_multiqc_reports.mix(TRIMMOMATIC.out.log)
        } else { ch_reads = ch_input }
    } else {
        ch_reads = ch_input
    }

    if (params.stop_at == 'qc') { return }

    // 2. PREPARE GENOME INDICES
    if (ref_is_gz) {
        SAMTOOLS_FAIDX(ch_ref)
        ch_ref_fai = SAMTOOLS_FAIDX.out.fai

        GATK_DICTIONARY(ch_ref)
        ch_ref_dict = GATK_DICTIONARY.out.dict
    } else {
        def fai_path = "${params.ref}.fai"
        if (file(fai_path).exists()) { ch_ref_fai = Channel.value(file(fai_path)) }
        else { SAMTOOLS_FAIDX(ch_ref); ch_ref_fai = SAMTOOLS_FAIDX.out.fai }

        def dict_path = "${params.ref.replaceAll(/(?i)\.(fa|fasta)(\.gz)?$/, '')}.dict"
        if (file(dict_path).exists()) { ch_ref_dict = Channel.value(file(dict_path)) }
        else { GATK_DICTIONARY(ch_ref); ch_ref_dict = GATK_DICTIONARY.out.dict }
    }

    if (params.aligner == 'bwa-mem2') {
        if (params.bwa_index && file(params.bwa_index).exists()) { ch_align_index = Channel.value(file(params.bwa_index)) } 
        else { BWA_INDEX(ch_ref); ch_align_index = BWA_INDEX.out.index }
    } else {
        if (params.bowtie2_index && file(params.bowtie2_index).exists()) { ch_align_index = Channel.value(file(params.bowtie2_index)) } 
        else { BOWTIE2_INDEX(ch_ref); ch_align_index = BOWTIE2_INDEX.out.index }
    }

    // 3. PREPARE ANNOTATION (For Qualimap)
    if (params.annotation) {
        if (params.annotation.endsWith('.gff') || params.annotation.endsWith('.gff3')) {
            GFF_TO_BED(file(params.annotation))
            ch_annot_bed = GFF_TO_BED.out.bed
        } else if (params.annotation.endsWith('.bed')) {
            ch_annot_bed = Channel.value(file(params.annotation, checkIfExists: true))
        } else { error "Annotation file must be .gff, .gff3, or .bed format" }
    } else { ch_annot_bed = Channel.value(file("$projectDir/assets/NO_FILE")) }

    // --- STEP 2: ALIGNMENT ---
    if (params.aligner == 'bwa-mem2') {
        BWA_ALIGN(ch_reads, ch_align_index, ref_prefix)
        SAMTOOLS_SORT_ALIGN(BWA_ALIGN.out.sam)
        ch_bams = SAMTOOLS_SORT_ALIGN.out.bam 
    } else {
        BOWTIE2_ALIGN(ch_reads, ch_align_index, ref_prefix)
        SAMTOOLS_SORT_ALIGN(BOWTIE2_ALIGN.out.sam)
        ch_bams = SAMTOOLS_SORT_ALIGN.out.bam 
    }

    // =========================================================
    // BRANCH A: ERROR ESTIMATION (Per-Library Processing)
    // =========================================================
    if (params.error_estimate) {
        
        // Isolate samples with >1 library by temporarily pulling 'meta.id' to the front as the grouping key
        ch_multi_libs = ch_bams
            .map { meta, bam -> tuple(meta.id, meta, bam) }
            .groupTuple(by: 0)
            .filter { id, metas, bams -> bams.size() > 1 }
            .flatMap { id, metas, bams -> 
                // Unpack back into standard [meta, bam] streams
                def result = []
                for (int i = 0; i < metas.size(); i++) { result.add(tuple(metas[i], bams[i])) }
                return result
            }
        
        def ch_error_dedup_bam

        if (params.markdup_tool == 'bamsormadup') {
            MARK_DUPLICATES_LIB_BAMSORMADUP(ch_multi_libs)
            ch_error_dedup_bam = MARK_DUPLICATES_LIB_BAMSORMADUP.out.dedup_bam
        } else if (params.markdup_tool == 'sambamba') {
            MARK_DUPLICATES_LIB_SAMBAMBA(ch_multi_libs)
            ch_error_dedup_bam = MARK_DUPLICATES_LIB_SAMBAMBA.out.dedup_bam
        } else if (params.markdup_tool == 'fastdup') {
            MARK_DUPLICATES_LIB_FASTDUP(ch_multi_libs)
            ch_error_dedup_bam = MARK_DUPLICATES_LIB_FASTDUP.out.dedup_bam
        } else {
            MARK_DUPLICATES_LIB(ch_multi_libs)
            ch_error_dedup_bam = MARK_DUPLICATES_LIB.out.dedup_bam
        }

        if (params.caller == 'gatk') {
            GATK_CALL_LIB(ch_error_dedup_bam, ch_ref, ch_ref_fai, ch_ref_dict)
            ch_lib_vcfs = GATK_CALL_LIB.out.vcf
        } else {
            FREEBAYES_CALL_LIB(ch_error_dedup_bam, ch_ref, ch_ref_fai)
            ch_lib_vcfs = FREEBAYES_CALL_LIB.out.vcf
        }

        // Compare library-level discordance before filtering.
        ch_vcfs_to_compare_raw = ch_lib_vcfs
            .map { meta, vcf, idx -> tuple(meta.id, vcf, idx) }
            .groupTuple(by: 0)
            .map { id, vcfs, idxs -> tuple([id: id], 'raw', vcfs, idxs) }

        VCF_MULTI_COMPARE_RAW(ch_vcfs_to_compare_raw, ch_vcf_compare_script)

        // Filter each library VCF, then compare discordance again after filtering.
        // Give each library a unique meta.id (sample_library) so VCF_FILTER_LIB output
        // filenames don't collide; also carry the original sample id for re-grouping.
        ch_lib_vcfs_for_filter = ch_lib_vcfs.map { meta, vcf, idx ->
            def lib_meta = [ id: "${meta.id}_${meta.library}", sample: meta.id, library: meta.library ]
            tuple(lib_meta, vcf)
        }
        VCF_FILTER_LIB(ch_lib_vcfs_for_filter)

        ch_filtered_for_compare = VCF_FILTER_LIB.out.filtered_vcf
            .join(VCF_FILTER_LIB.out.filtered_vcf_tbi, by: 0)
            .map { meta, vcf, tbi -> tuple(meta.sample, vcf, tbi) }

        ch_vcfs_to_compare_filtered = ch_filtered_for_compare
            .groupTuple(by: 0)
            .map { id, vcfs, idxs -> tuple([id: id], 'filtered', vcfs, idxs) }

        VCF_MULTI_COMPARE_FILTERED(ch_vcfs_to_compare_filtered, ch_vcf_compare_script)

        ch_error_reports = VCF_MULTI_COMPARE_RAW.out.report.mix(VCF_MULTI_COMPARE_FILTERED.out.report)
        VCF_DISCORDANCE_MQC(ch_error_reports.collect())
        ch_multiqc_reports = ch_multiqc_reports.mix(ch_error_reports)
        ch_multiqc_reports = ch_multiqc_reports.mix(VCF_DISCORDANCE_MQC.out.mqc_rate_csv)
        ch_multiqc_reports = ch_multiqc_reports.mix(VCF_DISCORDANCE_MQC.out.mqc_metrics_csv)
    }

    // =========================================================
    // BRANCH B: STANDARD WORKFLOW (Merged Processing)
    // =========================================================
    
    // Merge BAMs by creating a new meta map containing ONLY the sample ID
    ch_for_merge = ch_bams.map { meta, bam -> 
        def new_meta = [ id: meta.id ]
        tuple(new_meta, bam) 
    }.groupTuple()
    
    SAMTOOLS_MERGE(ch_for_merge)
    def ch_dedup_bam_for_call
    def ch_dedup_metrics

    if (params.markdup_tool == 'bamsormadup') {
        MARK_DUPLICATES_BAMSORMADUP(SAMTOOLS_MERGE.out.merged_bam)
        ch_dedup_bam_for_call = MARK_DUPLICATES_BAMSORMADUP.out.dedup_bam
        ch_dedup_metrics = MARK_DUPLICATES_BAMSORMADUP.out.metrics
    } else if (params.markdup_tool == 'sambamba') {
        MARK_DUPLICATES_SAMBAMBA(SAMTOOLS_MERGE.out.merged_bam)
        ch_dedup_bam_for_call = MARK_DUPLICATES_SAMBAMBA.out.dedup_bam
        ch_dedup_metrics = MARK_DUPLICATES_SAMBAMBA.out.metrics
    } else if (params.markdup_tool == 'fastdup') {
        MARK_DUPLICATES_FASTDUP(SAMTOOLS_MERGE.out.merged_bam)
        ch_dedup_bam_for_call = MARK_DUPLICATES_FASTDUP.out.dedup_bam
        ch_dedup_metrics = MARK_DUPLICATES_FASTDUP.out.metrics
    } else {
        MARK_DUPLICATES(SAMTOOLS_MERGE.out.merged_bam)
        ch_dedup_bam_for_call = MARK_DUPLICATES.out.dedup_bam
        ch_dedup_metrics = MARK_DUPLICATES.out.metrics
    }
    ch_multiqc_reports = ch_multiqc_reports.mix(ch_dedup_metrics)
    
    QUALIMAP(ch_dedup_bam_for_call, ch_annot_bed)
    // Note: Use .results if your module emits tuple(meta, dir), or .report if it emits path(dir)
    ch_multiqc_reports = ch_multiqc_reports.mix(QUALIMAP.out.results.map { meta, dir -> dir })

    if (params.stop_at == 'alignment') { return }

    // --- STEP 3: VARIANT CALLING ---
    ch_final_vcf = Channel.empty()

    if (params.caller == 'gatk') {
        // 1. Call individual gVCFs
        GATK_HAPLOTYPECALLER(ch_dedup_bam_for_call, ch_ref, ch_ref_fai, ch_ref_dict)
        
        // 2. Collect all gVCFs and indices into flat lists
        ch_gvcfs = GATK_HAPLOTYPECALLER.out.gvcf.map { meta, gvcf, tbi -> gvcf }.collect()
        ch_tbis  = GATK_HAPLOTYPECALLER.out.gvcf.map { meta, gvcf, tbi -> tbi }.collect()
        
        if (params.gvcf_joint_caller == 'glnexus') {
            GLNEXUS_COHORT(ch_gvcfs, ch_tbis)
            ch_final_vcf = GLNEXUS_COHORT.out.vcf.map { vcf -> tuple([id: "glnexus_joint"], vcf) }
        } else {
            // 3. Combine gVCFs
            GATK_COMBINEGVCFS(ch_gvcfs, ch_tbis, ch_ref, ch_ref_fai, ch_ref_dict)

            // 4. Joint Genotype the cohort
            GATK_GENOTYPEGVCFS(GATK_COMBINEGVCFS.out.gvcf, GATK_COMBINEGVCFS.out.tbi, ch_ref, ch_ref_fai, ch_ref_dict)

            // 5. Package for filtering
            ch_final_vcf = GATK_GENOTYPEGVCFS.out.vcf.map { vcf -> tuple([id: "gatk_joint"], vcf) }
        }
        
    } else if (params.caller == 'freebayes' && params.freebayes_mode == 'population') {
        // Collect cohort BAM/BAI files into separate channels.
        // Wrap each collected list in a one-element list so combine keeps
        // each payload as one field instead of flattening list elements.
        ch_population_bams = ch_dedup_bam_for_call
            .map { meta, bam, bai -> bam }
            .collect()
            .map { bams -> [bams] }

        ch_population_bais = ch_dedup_bam_for_call
            .map { meta, bam, bai -> bai }
            .collect()
            .map { bais -> [bais] }

        FREEBAYES_SPLIT_REGIONS(
            ch_ref_fai,
            Channel.value(params.freebayes_chunk_size)
        )

        ch_population_regions = FREEBAYES_SPLIT_REGIONS.out.regions
            .flatten()
            .map { region_file ->
                def chrom = region_file.baseName.replaceAll(/\.regions$/, '')
                tuple([id: chrom], region_file)
            }

        ch_population_jobs = ch_population_regions
            .combine(ch_population_bams)
            .combine(ch_population_bais)
            .combine(ch_ref)
            .combine(ch_ref_fai)
            .map { row ->
                def meta = row[0]
                def region_file = row[1]
                def bams = row[2]
                def bais = row[3]
                def ref = row[4]
                def ref_idx = row[5]
                tuple(meta, region_file, bams, bais, ref, ref_idx)
            }

        FREEBAYES_POPULATION(ch_population_jobs)

        ch_population_concat_inputs = FREEBAYES_POPULATION.out.vcf
            .map { meta, vcf, tbi -> tuple(vcf, tbi) }
            .toList()
            .map { shards -> tuple(shards.collect { it[0] }, shards.collect { it[1] }) }

        BCFTOOLS_CONCAT(ch_population_concat_inputs)
        ch_final_vcf = BCFTOOLS_CONCAT.out.vcf.map { vcf -> tuple([id: "population"], vcf) }
        
    } else {
        if (params.gvcf_joint_caller == 'glnexus') {
            // Freebayes + GLNexus path: emit per-sample gVCFs then cohort genotype with GLNexus.
            FREEBAYES_GVCF(ch_dedup_bam_for_call, ch_ref, ch_ref_fai)

            ch_freebayes_gvcfs = FREEBAYES_GVCF.out.gvcf.map { meta, gvcf, tbi -> gvcf }.collect()
            ch_freebayes_tbis  = FREEBAYES_GVCF.out.gvcf.map { meta, gvcf, tbi -> tbi }.collect()

            GLNEXUS_COHORT(ch_freebayes_gvcfs, ch_freebayes_tbis)
            ch_final_vcf = GLNEXUS_COHORT.out.vcf.map { vcf -> tuple([id: "glnexus_joint"], vcf) }
        } else {
            // Fallback: Individual Freebayes calling & standard merging
            FREEBAYES(ch_dedup_bam_for_call, ch_ref, ch_ref_fai)
            BCFTOOLS_MERGE(FREEBAYES.out.vcf.collect(), FREEBAYES.out.tbi.collect())
            ch_final_vcf = BCFTOOLS_MERGE.out.vcf.map { vcf -> tuple([id: "merged"], vcf) }
        }
    }

    if (params.stop_at == 'call') { return }

    // --- STEP 4: FILTERING & METRICS ---
    BCFTOOLS_STATS_RAW(ch_final_vcf)
    ch_multiqc_reports = ch_multiqc_reports.mix(BCFTOOLS_STATS_RAW.out.stats)

    VCF_FILTER_FINAL(ch_final_vcf)

    ch_filter_out = VCF_FILTER_FINAL.out.filtered_vcf
    ch_filter_out_tbi = VCF_FILTER_FINAL.out.filtered_vcf_tbi

    ch_filtered_vcf = ch_filter_out.map { meta, vcf -> tuple([id: "${meta.id}_filtered"], vcf) }

    BCFTOOLS_STATS_FILTERED(ch_filtered_vcf)
    ch_multiqc_reports = ch_multiqc_reports.mix(BCFTOOLS_STATS_FILTERED.out.stats)

    if (params.stop_at == 'filter') { return }
    // --- STEP 5: POPULATION GENETICS ---
    if (params.popgen) {
        ch_filtered_vcf_for_popgen = ch_filter_out
            .join(ch_filter_out_tbi, by: 0)
            .map { meta, vcf, tbi -> tuple(vcf, tbi) }
        POPGEN_ANALYSES(
            ch_filtered_vcf_for_popgen,
            ch_samplesheet,
            Channel.value(params.popgen_tree_method),
            Channel.value(params.popgen_legend_order),
            ch_popgen_script
        )
        ch_multiqc_reports = ch_multiqc_reports.mix(POPGEN_ANALYSES.out.pca_mqc)
        ch_multiqc_reports = ch_multiqc_reports.mix(POPGEN_ANALYSES.out.tree_mqc)
    }
    if (params.stop_at == 'popgen') { return }
    // --- FINAL STEP: MULTIQC ---

    GENERATE_SOFTWARE_VERSIONS_MQC(
        Channel.value(params.trimmer),
        Channel.value(params.aligner),
        Channel.value(params.caller),
        Channel.value(params.markdup_tool),
        Channel.value(params.annotation),
        Channel.value(params.popgen)
    )

    ch_multiqc_reports = ch_multiqc_reports.mix(GENERATE_SOFTWARE_VERSIONS_MQC.out.versions)
    
    // Pass config and logo so both are staged in the work directory
    MULTIQC(ch_multiqc_reports.collect(), ch_multiqc_config, ch_multiqc_logo)

}