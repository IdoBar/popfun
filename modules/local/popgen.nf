process POPGEN_ANALYSES {
    label 'sc_medium'
    conda "conda-forge::python=3.9 conda-forge::numpy=1.23.5 bioconda::pysam=0.19.1 bioconda::iqtree=2.4.0 bioconda::mrbayes=3.2.7"
    container 'ghcr.io/idobar/popgen:latest'

    input:
    tuple path(vcf), path(vcf_tbi)
    path samplesheet
    val tree_method
    val legend_order
    path popgen_script

    output:
    path "popgen_pca_mqc.txt", emit: pca_mqc
    path "popgen_tree_mqc.txt", emit: tree_mqc
    path "popgen_tree.newick", emit: tree_newick
    path "popgen_pca_coords.csv", emit: pca_coords

    script:
    """
    python "$popgen_script" \
        --vcf "$vcf" \
        --samplesheet "$samplesheet" \
        --tree-method "$tree_method" \
        --legend-order "$legend_order"
    """
}
