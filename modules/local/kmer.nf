// Save as: modules/local/kmer.nf

def canonicalSampleLibraryId = { meta ->
    def sampleId = meta.id?.toString()?.trim()
    def libraryId = meta.library?.toString()?.trim()
    def collapsedSampleId = sampleId

    if (sampleId) {
        def repeatedSampleMatcher = (sampleId =~ /^(.*)_\1$/)
        if (repeatedSampleMatcher.matches()) {
            collapsedSampleId = repeatedSampleMatcher[0][1]
        }
    }

    def sampleLibraryId = (collapsedSampleId && libraryId)
        ? (collapsedSampleId.endsWith("_${libraryId}") ? collapsedSampleId : "${collapsedSampleId}_${libraryId}")
        : (meta.unit_id ?: meta.library ?: meta.id).toString()

    return sampleLibraryId.replaceAll(/[^A-Za-z0-9._-]+/, '_')
}

process SOURMASH_SKETCH {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::sourmash=4.9.4"
    container 'quay.io/biocontainers/sourmash:4.9.4--hdfd78af_0'

    input:
        tuple val(meta), path(read1), path(read2)

    output:
        tuple val(meta), path("*.sig"), emit: signature

    script:
    def args = task.ext.args ?: ''
    def unitId = canonicalSampleLibraryId(meta)
    def ksize = params.kmer ?: (params.kmer_sourmash_k ?: 31)
    def scaled = params.kmer_sourmash_scaled ?: 1000
    def sketchArgs = params.kmer_sourmash_args ?: ''
    """
    sourmash sketch dna -p scaled=${scaled},k=${ksize} $sketchArgs --name ${unitId} -o ${unitId}.sig "$read1" "$read2"
    """
}

process SOURMASH_COMPARE {
    tag 'sourmash_compare'
    label 'mc_medium'
    conda "bioconda::sourmash=4.9.4"
    container 'quay.io/biocontainers/sourmash:4.9.4--hdfd78af_0'

    input:
        path(signatures)

    output:
        path "sourmash_compare_bundle", emit: compare

    script:
    def compareArgs = params.kmer_sourmash_compare_args ?: ''
    def signatureFiles = signatures.collect { it.toString().tokenize('/').last() }.join(' ')
    """
    mkdir -p sourmash_compare_bundle
    sourmash compare -p ${task.cpus} $compareArgs $signatureFiles -o sourmash_compare_bundle/sourmash_compare
    sourmash plot --pdf --labels sourmash_compare_bundle/sourmash_compare
    """
}

process KAT_HIST {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::kat=2.4.2"
    container 'quay.io/biocontainers/kat:2.4.2--py39he0b6574_5'

    input:
        tuple val(meta), path(read1), path(read2)

    output:
        path "*.kat_hist*", emit: hist

    script:
    def args = params.kmer_kat_args ?: ''
    def unitId = canonicalSampleLibraryId(meta)
    def katThreads = params.kmer_kat_threads ?: 1
    def kmerSize = params.kmer ?: (params.kmer_sourmash_k ?: 31)
    """
    export MPLCONFIGDIR="${PWD}/.mplconfig"
    export XDG_CONFIG_HOME="${PWD}/.config"
    mkdir -p "${PWD}/.mplconfig" "${PWD}/.config"
    set +e
    kat hist -m ${kmerSize} -t ${katThreads} -o ${unitId}.kat_hist $args "$read1" "$read2"
    rc=\$?
    set -e
    if [[ \$rc -ne 0 ]]; then
        if [[ \$rc -eq 134 ]] && ls ${unitId}.kat_hist* >/dev/null 2>&1; then
            echo "KAT hist exited with 134 after generating outputs; continuing" >&2
        else
            exit \$rc
        fi
    fi
    """
}

process KAT_GCP {
    tag "${meta.unit_id ?: meta.library ?: meta.id}"
    label 'mc_medium'
    conda "bioconda::kat=2.4.2"
    container 'quay.io/biocontainers/kat:2.4.2--py39he0b6574_5'

    input:
        tuple val(meta), path(read1), path(read2)

    output:
        path "*.kat_gcp*", emit: gcp

    script:
    def args = params.kmer_kat_args ?: ''
    def unitId = canonicalSampleLibraryId(meta)
    def katThreads = params.kmer_kat_threads ?: 1
    def kmerSize = params.kmer ?: (params.kmer_sourmash_k ?: 31)
    """
    export MPLCONFIGDIR="${PWD}/.mplconfig"
    export XDG_CONFIG_HOME="${PWD}/.config"
    mkdir -p "${PWD}/.mplconfig" "${PWD}/.config"
    set +e
    kat gcp -m ${kmerSize} -t ${katThreads} -o ${unitId}.kat_gcp $args "$read1" "$read2"
    rc=\$?
    set -e
    if [[ \$rc -ne 0 ]]; then
        if [[ \$rc -eq 134 ]] && ls ${unitId}.kat_gcp* >/dev/null 2>&1; then
            echo "KAT gcp exited with 134 after generating outputs; continuing" >&2
        else
            exit \$rc
        fi
    fi
    """
}