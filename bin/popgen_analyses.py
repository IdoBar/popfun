#!/usr/bin/env python3

import argparse
import csv
import math
import os
import shutil
import subprocess
from itertools import combinations

import numpy as np
import pysam


def read_pop_map(path):
    pop_map = {}
    pop_first_seen = []
    with open(path, newline='') as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            # Normalize headers so we can match by name regardless of CSV column order or header casing/spacing.
            norm_row = {
                str(k).strip().lower(): (v if v is not None else '')
                for k, v in row.items()
                if k is not None
            }
            sample = str(norm_row.get('sample', '')).strip()
            if not sample:
                continue
            pop = str(norm_row.get('pop', '')).strip() or 'NA'
            if pop not in pop_first_seen:
                pop_first_seen.append(pop)
            pop_map[sample] = pop
    return pop_map, pop_first_seen


def gt_to_dosage(gt):
    if gt is None:
        return None
    alleles = [a for a in gt if a is not None and a >= 0]
    if not alleles:
        return None
    return float(sum(alleles))


def pca_scores(matrix, n_comp=3):
    x = np.array(matrix, dtype=float)
    if x.size == 0:
        return np.zeros((0, n_comp), dtype=float)

    # Impute missing genotype dosages by per-variant mean.
    col_mean = np.nanmean(x, axis=0)
    col_mean = np.where(np.isnan(col_mean), 0.0, col_mean)
    inds = np.where(np.isnan(x))
    x[inds] = col_mean[inds[1]]

    # Center variants and run SVD on sample x variant matrix.
    x = x - np.mean(x, axis=0)
    if x.shape[0] < 2 or x.shape[1] < 1:
        out = np.zeros((x.shape[0], n_comp), dtype=float)
        return out

    u, s, _vt = np.linalg.svd(x, full_matrices=False)
    pcs = u * s
    if pcs.shape[1] < n_comp:
        pad = np.zeros((pcs.shape[0], n_comp - pcs.shape[1]), dtype=float)
        pcs = np.hstack([pcs, pad])
    return pcs[:, :n_comp]


class Node:
    def __init__(self, name=None, left=None, right=None, height=0.0):
        self.name = name
        self.left = left
        self.right = right
        self.height = height

    @property
    def is_leaf(self):
        return self.name is not None


def upgma(sample_names, dist_matrix):
    clusters = {i: Node(name=sample_names[i], height=0.0) for i in range(len(sample_names))}
    members = {i: [i] for i in range(len(sample_names))}
    active = list(clusters.keys())
    next_id = len(sample_names)

    def avg_dist(a, b):
        vals = []
        for i in members[a]:
            for j in members[b]:
                if i == j:
                    continue
                ii, jj = (i, j) if i < j else (j, i)
                vals.append(dist_matrix[(ii, jj)])
        return sum(vals) / max(len(vals), 1)

    while len(active) > 1:
        best_pair = None
        best_d = None
        for a, b in combinations(active, 2):
            d = avg_dist(a, b)
            if best_d is None or d < best_d:
                best_d = d
                best_pair = (a, b)

        a, b = best_pair
        h = max(best_d / 2.0, clusters[a].height, clusters[b].height)
        clusters[next_id] = Node(left=clusters[a], right=clusters[b], height=h)
        members[next_id] = members[a] + members[b]

        active = [x for x in active if x not in (a, b)]
        active.append(next_id)
        next_id += 1

    return clusters[active[0]]


def _dkey(a, b):
    return (a, b) if a < b else (b, a)


def _dget(dmap, a, b):
    if a == b:
        return 0.0
    return dmap[_dkey(a, b)]


def neighbor_joining(sample_names, dist_matrix):
    n0 = len(sample_names)
    if n0 == 1:
        return Node(name=sample_names[0], height=0.0)
    if n0 == 2:
        return Node(left=Node(name=sample_names[0], height=0.0), right=Node(name=sample_names[1], height=0.0), height=1.0)

    dmap = dict(dist_matrix)
    clusters = {i: Node(name=sample_names[i], height=0.0) for i in range(n0)}
    active = list(clusters.keys())
    next_id = n0

    while len(active) > 2:
        n = len(active)
        r = {i: sum(_dget(dmap, i, j) for j in active if j != i) for i in active}

        best_pair = None
        best_q = None
        for a, b in combinations(active, 2):
            q = (n - 2) * _dget(dmap, a, b) - r[a] - r[b]
            if best_q is None or q < best_q:
                best_q = q
                best_pair = (a, b)

        a, b = best_pair
        u = next_id
        next_id += 1

        clusters[u] = Node(left=clusters[a], right=clusters[b], height=max(clusters[a].height, clusters[b].height) + 1.0)

        for k in list(active):
            if k in (a, b):
                continue
            duk = 0.5 * (_dget(dmap, a, k) + _dget(dmap, b, k) - _dget(dmap, a, b))
            dmap[_dkey(u, k)] = max(duk, 0.0)

        for k in list(active):
            if k in (a, b):
                continue
            dmap.pop(_dkey(a, k), None)
            dmap.pop(_dkey(b, k), None)
        dmap.pop(_dkey(a, b), None)

        active = [x for x in active if x not in (a, b)]
        active.append(u)

    a, b = active
    return Node(left=clusters[a], right=clusters[b], height=max(clusters[a].height, clusters[b].height) + 1.0)


def to_newick(node, parent_h=None):
    if node.is_leaf:
        return node.name

    left = to_newick(node.left)
    right = to_newick(node.right)
    label = f"({left},{right})"
    if parent_h is None:
        return label + ';'
    return label


def palette_for_pops(ordered_pops):
    base = [
        '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
        '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
    ]
    return {p: base[i % len(base)] for i, p in enumerate(ordered_pops)}


def ordered_pops(samples, pop_map, pop_first_seen, legend_order):
    present = {pop_map.get(s, 'NA') for s in samples}
    if legend_order == 'alphabetical':
        return sorted(present)

    ordered = [p for p in pop_first_seen if p in present]
    tail = sorted([p for p in present if p not in ordered])
    return ordered + tail


def run_cmd(cmd):
    p = subprocess.run(cmd, text=True, capture_output=True)
    if p.returncode != 0:
        max_chars = 8000
        stdout = p.stdout[-max_chars:]
        stderr = p.stderr[-max_chars:]
        raise RuntimeError(
            f"Command failed ({' '.join(cmd)}):\n"
            f"STDOUT(tail):\n{stdout}\n"
            f"STDERR(tail):\n{stderr}"
        )
    return p


def allele_to_base(rec, allele_idx):
    if allele_idx is None or allele_idx < 0:
        return 'N'
    alleles = [rec.ref] + list(rec.alts or [])
    if allele_idx >= len(alleles):
        return 'N'
    base = str(alleles[allele_idx]).upper()
    return base if len(base) == 1 else 'N'


def gt_to_base(rec, gt):
    if gt is None or len(gt) == 0 or any(a is None or a < 0 for a in gt):
        return 'N'

    # Haploid or homozygous diploid.
    if len(gt) == 1 or (len(gt) >= 2 and gt[0] == gt[1]):
        return allele_to_base(rec, gt[0])

    # IUPAC code for heterozygous diploid SNPs.
    b1 = allele_to_base(rec, gt[0])
    b2 = allele_to_base(rec, gt[1])
    pair = ''.join(sorted([b1, b2]))
    iupac = {
        'AC': 'M', 'AG': 'R', 'AT': 'W',
        'CG': 'S', 'CT': 'Y', 'GT': 'K'
    }
    return iupac.get(pair, 'N')


def write_alignment_files(vcf_path, sample_names):
    vf = pysam.VariantFile(vcf_path)
    seqs = {s: [] for s in sample_names}
    nchar = 0

    for rec in vf:
        alleles = [rec.ref] + list(rec.alts or [])
        # Restrict alignment to clean bi-allelic SNP sites.
        if len(alleles) != 2:
            continue
        if any(len(str(a)) != 1 for a in alleles):
            continue

        for s in sample_names:
            gt = rec.samples[s].get('GT')
            seqs[s].append(gt_to_base(rec, gt))
        nchar += 1

    if nchar == 0:
        raise RuntimeError('No bi-allelic SNP sites available to build alignment for ML/Bayesian tree.')

    with open('popgen_alignment.fasta', 'w') as fh:
        for s in sample_names:
            fh.write(f">{s}\n{''.join(seqs[s])}\n")

    with open('popgen_alignment.nex', 'w') as fh:
        fh.write('#NEXUS\n')
        fh.write('Begin data;\n')
        fh.write(f'  Dimensions ntax={len(sample_names)} nchar={nchar};\n')
        fh.write('  Format datatype=dna gap=- missing=N;\n')
        fh.write('  Matrix\n')
        for s in sample_names:
            fh.write(f'  {s} {"".join(seqs[s])}\n')
        fh.write('  ;\nEnd;\n')


def run_iqtree_ml():
    iqtree_bin = shutil.which('iqtree2') or shutil.which('iqtree')
    if not iqtree_bin:
        raise RuntimeError('Neither iqtree2 nor iqtree was found in PATH. Install IQ-TREE for --tree-method ml.')
    run_cmd([iqtree_bin, '-s', 'popgen_alignment.fasta', '-m', 'GTR+ASC+G', '-nt', 'AUTO', '-redo', '-quiet'])
    with open('popgen_alignment.fasta.treefile') as fh:
        return fh.read().strip()


def run_mrbayes():
    with open('popgen_mb_run.nex', 'w') as fh:
        fh.write('#NEXUS\n')
        fh.write('execute popgen_alignment.nex;\n')
        fh.write('begin mrbayes;\n')
        fh.write('  set autoclose=yes nowarn=yes;\n')
        fh.write('  lset coding=variable;\n')
        fh.write('  lset nst=6 rates=gamma;\n')
        fh.write('  mcmcp ngen=10000 samplefreq=100 printfreq=100 diagnfreq=500 nchains=4 burninfrac=0.25;\n')
        fh.write('  mcmc;\n')
        fh.write('  sumt;\n')
        fh.write('end;\n')

    run_cmd(['mb', 'popgen_mb_run.nex'])

    tree_line = None
    with open('popgen_alignment.nex.con.tre') as fh:
        for line in fh:
            s = line.strip()
            if s.lower().startswith('tree ') and '=' in s:
                tree_line = s
    if tree_line is None:
        raise RuntimeError('MrBayes did not produce a consensus tree line in popgen_alignment.nex.con.tre')

    newick = tree_line.split('=', 1)[1].strip()
    if newick.startswith('[&U]'):
        newick = newick[len('[&U]'):].strip()
    return newick


def scale(vals, lo, hi):
    vmin = min(vals) if vals else 0.0
    vmax = max(vals) if vals else 1.0
    if math.isclose(vmin, vmax):
        return [0.5 * (lo + hi) for _ in vals]
    return [lo + (v - vmin) * (hi - lo) / (vmax - vmin) for v in vals]


def build_pca_svg(samples, pops, pcs, cmap):
    width, height = 900, 520
    left, right, top, bottom = 70, 620, 40, 470

    pc1 = pcs[:, 0].tolist() if len(samples) else []
    pc2 = pcs[:, 1].tolist() if len(samples) else []
    pc3 = pcs[:, 2].tolist() if len(samples) else []

    x = scale(pc1, left, right)
    y = scale(pc2, bottom, top)
    r = scale(pc3, 5, 13)

    parts = [
        f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' viewBox='0 0 {width} {height}'>",
        "<rect x='0' y='0' width='100%' height='100%' fill='white'/>",
        f"<line x1='{left}' y1='{bottom}' x2='{right}' y2='{bottom}' stroke='#333' stroke-width='1.2'/>",
        f"<line x1='{left}' y1='{bottom}' x2='{left}' y2='{top}' stroke='#333' stroke-width='1.2'/>",
        f"<text x='{(left + right) / 2}' y='{height - 20}' text-anchor='middle' font-size='14'>PC1</text>",
        f"<text x='20' y='{(top + bottom) / 2}' text-anchor='middle' font-size='14' transform='rotate(-90 20 {(top + bottom) / 2})'>PC2</text>",
        "<text x='70' y='20' font-size='14'>Marker radius encodes PC3 magnitude</text>",
    ]

    for i, s in enumerate(samples):
        color = cmap[pops[i]]
        parts.append(
            f"<circle cx='{x[i]:.2f}' cy='{y[i]:.2f}' r='{r[i]:.2f}' fill='{color}' fill-opacity='0.78' stroke='#222' stroke-width='0.6'>"
            f"<title>{s} | pop={pops[i]} | PC1={pc1[i]:.4f} PC2={pc2[i]:.4f} PC3={pc3[i]:.4f}</title></circle>"
        )

    # Legend
    lx, ly = 670, 60
    parts.append(f"<text x='{lx}' y='{ly - 18}' font-size='14'>Population</text>")
    for idx, pop in enumerate(cmap.keys()):
        yy = ly + idx * 22
        parts.append(f"<rect x='{lx}' y='{yy - 10}' width='14' height='14' fill='{cmap[pop]}' stroke='#222' stroke-width='0.5'/>")
        parts.append(f"<text x='{lx + 22}' y='{yy + 1}' font-size='12'>{pop}</text>")

    parts.append("</svg>")
    return ''.join(parts)


def assign_leaf_y(node, out, start=40, step=24):
    if node.is_leaf:
        out[node.name] = start + len(out) * step
        return
    assign_leaf_y(node.left, out, start, step)
    assign_leaf_y(node.right, out, start, step)


def collect_segments(node, leaf_y, max_h, x0=50, x1=820, segs=None):
    if segs is None:
        segs = []

    def x(h):
        if max_h <= 0:
            return x0
        return x0 + (h / max_h) * (x1 - x0)

    if node.is_leaf:
        return x(node.height), leaf_y[node.name], segs

    lx, ly, segs = collect_segments(node.left, leaf_y, max_h, x0, x1, segs)
    rx, ry, segs = collect_segments(node.right, leaf_y, max_h, x0, x1, segs)
    px = x(node.height)

    segs.append((lx, ly, px, ly))
    segs.append((rx, ry, px, ry))
    segs.append((px, min(ly, ry), px, max(ly, ry)))

    return px, (ly + ry) / 2.0, segs


def build_tree_svg(root, pop_map, cmap, tree_method):
    leaves = []

    def get_leaves(n):
        if n.is_leaf:
            leaves.append(n.name)
            return
        get_leaves(n.left)
        get_leaves(n.right)

    get_leaves(root)
    leaf_y = {}
    assign_leaf_y(root, leaf_y, start=40, step=26)
    max_h = root.height if root else 0.0

    width = 950
    height = max(220, 80 + 26 * len(leaves))
    segs = []
    collect_segments(root, leaf_y, max_h, x0=70, x1=760, segs=segs)

    parts = [
        f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' viewBox='0 0 {width} {height}'>",
        "<rect x='0' y='0' width='100%' height='100%' fill='white'/>",
        f"<text x='70' y='22' font-size='14'>{tree_method.upper()} tree built from Euclidean distances over PC1-PC3</text>",
    ]

    for x1, y1, x2, y2 in segs:
        parts.append(f"<line x1='{x1:.2f}' y1='{y1:.2f}' x2='{x2:.2f}' y2='{y2:.2f}' stroke='#333' stroke-width='1.1'/>")

    for s in leaves:
        y = leaf_y[s]
        pop = pop_map.get(s, 'NA')
        c = cmap[pop]
        parts.append(f"<circle cx='770' cy='{y:.2f}' r='4.5' fill='{c}' stroke='#222' stroke-width='0.6'/>")
        parts.append(f"<text x='780' y='{y + 4:.2f}' font-size='12'>{s} ({pop})</text>")

    lx, ly = 70, height - 18 - 22 * len(cmap)
    parts.append(f"<text x='{lx}' y='{ly - 10}' font-size='13'>Population colors</text>")
    for i, pop in enumerate(cmap.keys()):
        yy = ly + i * 20
        parts.append(f"<rect x='{lx}' y='{yy - 10}' width='12' height='12' fill='{cmap[pop]}' stroke='#222' stroke-width='0.5'/>")
        parts.append(f"<text x='{lx + 18}' y='{yy}' font-size='11'>{pop}</text>")

    parts.append("</svg>")
    return ''.join(parts)


def parse_args():
    p = argparse.ArgumentParser(description='Population genetics PCA + tree report generator for MultiQC.')
    p.add_argument('--vcf', required=True, help='Input cohort VCF path')
    p.add_argument('--samplesheet', required=True, help='Samplesheet CSV path (must contain sample and optional pop columns)')
    p.add_argument('--tree-method', required=True, choices=['upgma', 'nj', 'ml', 'bayesian'], help='Tree method')
    p.add_argument('--legend-order', required=True, choices=['samplesheet', 'alphabetical'], help='Legend order')
    return p.parse_args()


def main():
    args = parse_args()
    tree_method = args.tree_method.strip().lower()
    legend_order = args.legend_order.strip().lower()

    pop_map, pop_first_seen = read_pop_map(args.samplesheet)

    vcf_path = args.vcf
    if not os.path.exists(vcf_path):
        raise RuntimeError(f"Input VCF was not staged: {vcf_path}")

    vf = pysam.VariantFile(vcf_path)
    samples = list(vf.header.samples)

    if len(samples) == 0:
        raise RuntimeError('Population VCF has no samples in header.')

    rows = []
    for rec in vf:
        d = []
        for s in samples:
            gt = rec.samples[s].get('GT')
            d.append(gt_to_dosage(gt))
        rows.append(d)

    if len(rows) == 0:
        # still emit empty, valid sections
        pcs = np.zeros((len(samples), 3), dtype=float)
    else:
        x = np.array(rows, dtype=float).T  # sample x variant
        pcs = pca_scores(x, n_comp=3)

    with open('popgen_pca_coords.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['sample', 'pop', 'PC1', 'PC2', 'PC3'])
        for i, s in enumerate(samples):
            pop = pop_map.get(s, 'NA')
            w.writerow([s, pop, round(float(pcs[i, 0]), 6), round(float(pcs[i, 1]), 6), round(float(pcs[i, 2]), 6)])

    # Distance matrix from PC space.
    dist = {}
    for i in range(len(samples)):
        for j in range(i + 1, len(samples)):
            dij = float(np.linalg.norm(pcs[i, :3] - pcs[j, :3]))
            dist[(i, j)] = dij

    if len(samples) == 1:
        root = Node(name=samples[0], height=0.0)
        newick = f"{samples[0]};"
    else:
        if tree_method in ('upgma', 'nj'):
            root = upgma(samples, dist) if tree_method == 'upgma' else neighbor_joining(samples, dist)
            newick = to_newick(root)
        else:
            write_alignment_files(vcf_path, samples)
            root = None
            newick = run_iqtree_ml() if tree_method == 'ml' else run_mrbayes()

    with open('popgen_tree.newick', 'w') as fh:
        fh.write(newick + '\n')

    pops = [pop_map.get(s, 'NA') for s in samples]
    legend_pops = ordered_pops(samples, pop_map, pop_first_seen, legend_order)
    cmap = palette_for_pops(legend_pops)
    pca_svg = build_pca_svg(samples, pops, pcs, cmap)
    if root is not None:
        tree_svg = build_tree_svg(root, pop_map, cmap, tree_method)
    else:
        tree_svg = (
            f"<p><b>{tree_method.upper()} tree inference completed.</b></p>"
            "<p>Rendered tree graphics are available in exported outputs; Newick is shown below.</p>"
        )

    pca_html = (
        "# id: 'popgen_pca'\n"
        "# section_name: 'Population Genetics: PCA (PC1-PC3)'\n"
        "# description: 'Principal component analysis from population VCF genotype dosages. Point color uses samplesheet pop column.'\n"
        "# plot_type: 'html'\n"
        + pca_svg + "\n"
    )

    with open('popgen_pca_mqc.txt', 'w') as fh:
        fh.write(pca_html)

    tree_html = (
        "# id: 'popgen_tree'\n"
        "# section_name: 'Population Genetics: Phylogenetic Tree'\n"
        "# description: 'Tree built from Euclidean distances over PCA components (PC1-PC3) using selected method. Leaf colors use samplesheet pop column.'\n"
        "# plot_type: 'html'\n"
        "<p><b>Newick:</b> <code>" + newick.replace('<', '&lt;').replace('>', '&gt;') + "</code></p>\n"
        + tree_svg + "\n"
    )

    with open('popgen_tree_mqc.txt', 'w') as fh:
        fh.write(tree_html)


if __name__ == '__main__':
    main()
#!/usr/bin/env python3

import argparse
import csv
import math
import os
import shutil
import subprocess
from itertools import combinations

import numpy as np
import pysam


def read_pop_map(path):
    pop_map = {}
    pop_first_seen = []
    with open(path, newline='') as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            norm_row = {
                str(k).strip().lower(): (v if v is not None else '')
                for k, v in row.items()
                if k is not None
            }
            sample = str(norm_row.get('sample', '')).strip()
            if not sample:
                continue
            pop = str(norm_row.get('pop', '')).strip() or 'NA'
            if pop not in pop_first_seen:
                pop_first_seen.append(pop)
            pop_map[sample] = pop
    return pop_map, pop_first_seen


def gt_to_dosage(gt):
    if gt is None:
        return None
    alleles = [a for a in gt if a is not None and a >= 0]
    if not alleles:
        return None
    return float(sum(alleles))


def pca_scores(matrix, n_comp=3):
    x = np.array(matrix, dtype=float)
    if x.size == 0:
        return np.zeros((0, n_comp), dtype=float)

    col_mean = np.nanmean(x, axis=0)
    col_mean = np.where(np.isnan(col_mean), 0.0, col_mean)
    inds = np.where(np.isnan(x))
    x[inds] = col_mean[inds[1]]

    x = x - np.mean(x, axis=0)
    if x.shape[0] < 2 or x.shape[1] < 1:
        out = np.zeros((x.shape[0], n_comp), dtype=float)
        return out

    u, s, _vt = np.linalg.svd(x, full_matrices=False)
    pcs = u * s
    if pcs.shape[1] < n_comp:
        pad = np.zeros((pcs.shape[0], n_comp - pcs.shape[1]), dtype=float)
        pcs = np.hstack([pcs, pad])
    return pcs[:, :n_comp]


class Node:
    def __init__(self, name=None, left=None, right=None, height=0.0):
        self.name = name
        self.left = left
        self.right = right
        self.height = height

    @property
    def is_leaf(self):
        return self.name is not None


def upgma(sample_names, dist_matrix):
    clusters = {i: Node(name=sample_names[i], height=0.0) for i in range(len(sample_names))}
    members = {i: [i] for i in range(len(sample_names))}
    active = list(clusters.keys())
    next_id = len(sample_names)

    def avg_dist(a, b):
        vals = []
        for i in members[a]:
            for j in members[b]:
                if i == j:
                    continue
                ii, jj = (i, j) if i < j else (j, i)
                vals.append(dist_matrix[(ii, jj)])
        return sum(vals) / max(len(vals), 1)

    while len(active) > 1:
        best_pair = None
        best_d = None
        for a, b in combinations(active, 2):
            d = avg_dist(a, b)
            if best_d is None or d < best_d:
                best_d = d
                best_pair = (a, b)

        a, b = best_pair
        h = max(best_d / 2.0, clusters[a].height, clusters[b].height)
        clusters[next_id] = Node(left=clusters[a], right=clusters[b], height=h)
        members[next_id] = members[a] + members[b]

        active = [x for x in active if x not in (a, b)]
        active.append(next_id)
        next_id += 1

    return clusters[active[0]]


def _dkey(a, b):
    return (a, b) if a < b else (b, a)


def _dget(dmap, a, b):
    if a == b:
        return 0.0
    return dmap[_dkey(a, b)]


def neighbor_joining(sample_names, dist_matrix):
    n0 = len(sample_names)
    if n0 == 1:
        return Node(name=sample_names[0], height=0.0)
    if n0 == 2:
        return Node(left=Node(name=sample_names[0], height=0.0), right=Node(name=sample_names[1], height=0.0), height=1.0)

    dmap = dict(dist_matrix)
    clusters = {i: Node(name=sample_names[i], height=0.0) for i in range(n0)}
    active = list(clusters.keys())
    next_id = n0

    while len(active) > 2:
        n = len(active)
        r = {i: sum(_dget(dmap, i, j) for j in active if j != i) for i in active}

        best_pair = None
        best_q = None
        for a, b in combinations(active, 2):
            q = (n - 2) * _dget(dmap, a, b) - r[a] - r[b]
            if best_q is None or q < best_q:
                best_q = q
                best_pair = (a, b)

        a, b = best_pair
        u = next_id
        next_id += 1

        clusters[u] = Node(left=clusters[a], right=clusters[b], height=max(clusters[a].height, clusters[b].height) + 1.0)

        for k in list(active):
            if k in (a, b):
                continue
            duk = 0.5 * (_dget(dmap, a, k) + _dget(dmap, b, k) - _dget(dmap, a, b))
            dmap[_dkey(u, k)] = max(duk, 0.0)

        for k in list(active):
            if k in (a, b):
                continue
            dmap.pop(_dkey(a, k), None)
            dmap.pop(_dkey(b, k), None)
        dmap.pop(_dkey(a, b), None)

        active = [x for x in active if x not in (a, b)]
        active.append(u)

    a, b = active
    return Node(left=clusters[a], right=clusters[b], height=max(clusters[a].height, clusters[b].height) + 1.0)


def to_newick(node, parent_h=None):
    if node.is_leaf:
        return node.name

    left = to_newick(node.left)
    right = to_newick(node.right)
    label = f"({left},{right})"
    if parent_h is None:
        return label + ';'
    return label


def palette_for_pops(ordered_pops):
    base = [
        '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
        '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
    ]
    return {p: base[i % len(base)] for i, p in enumerate(ordered_pops)}


def ordered_pops(samples, pop_map, pop_first_seen, legend_order):
    present = {pop_map.get(s, 'NA') for s in samples}
    if legend_order == 'alphabetical':
        return sorted(present)

    ordered = [p for p in pop_first_seen if p in present]
    tail = sorted([p for p in present if p not in ordered])
    return ordered + tail


def run_cmd(cmd):
    p = subprocess.run(cmd, text=True, capture_output=True)
    if p.returncode != 0:
        stdout = (p.stdout or '')[-4000:]
        stderr = (p.stderr or '')[-4000:]
        raise RuntimeError(
            f"Command failed ({' '.join(cmd)}):\nSTDOUT (tail):\n{stdout}\nSTDERR (tail):\n{stderr}"
        )
    return p


def allele_to_base(rec, allele_idx):
    if allele_idx is None or allele_idx < 0:
        return 'N'
    alleles = [rec.ref] + list(rec.alts or [])
    if allele_idx >= len(alleles):
        return 'N'
    base = str(alleles[allele_idx]).upper()
    return base if len(base) == 1 else 'N'


def gt_to_base(rec, gt):
    if gt is None or len(gt) == 0 or any(a is None or a < 0 for a in gt):
        return 'N'

    if len(gt) == 1 or (len(gt) >= 2 and gt[0] == gt[1]):
        return allele_to_base(rec, gt[0])

    b1 = allele_to_base(rec, gt[0])
    b2 = allele_to_base(rec, gt[1])
    pair = ''.join(sorted([b1, b2]))
    iupac = {
        'AC': 'M', 'AG': 'R', 'AT': 'W',
        'CG': 'S', 'CT': 'Y', 'GT': 'K'
    }
    return iupac.get(pair, 'N')


def write_alignment_files(vcf_path, sample_names):
    vf = pysam.VariantFile(vcf_path)
    seqs = {s: [] for s in sample_names}
    nchar = 0

    for rec in vf:
        alleles = [rec.ref] + list(rec.alts or [])
        if len(alleles) != 2:
            continue
        if any(len(str(a)) != 1 for a in alleles):
            continue

        for s in sample_names:
            gt = rec.samples[s].get('GT')
            seqs[s].append(gt_to_base(rec, gt))
        nchar += 1

    if nchar == 0:
        raise RuntimeError('No bi-allelic SNP sites available to build alignment for ML/Bayesian tree.')

    with open('popgen_alignment.fasta', 'w') as fh:
        for s in sample_names:
            fh.write(f">{s}\n{''.join(seqs[s])}\n")

    with open('popgen_alignment.nex', 'w') as fh:
        fh.write('#NEXUS\n')
        fh.write('Begin data;\n')
        fh.write(f'  Dimensions ntax={len(sample_names)} nchar={nchar};\n')
        fh.write('  Format datatype=dna gap=- missing=N;\n')
        fh.write('  Matrix\n')
        for s in sample_names:
            fh.write(f'  {s} {"".join(seqs[s])}\n')
        fh.write('  ;\nEnd;\n')


def run_iqtree_ml():
    iqtree_bin = shutil.which('iqtree2') or shutil.which('iqtree')
    if not iqtree_bin:
        raise RuntimeError('Neither iqtree2 nor iqtree was found in PATH. Install IQ-TREE for --tree-method ml.')
    run_cmd([iqtree_bin, '-s', 'popgen_alignment.fasta', '-m', 'GTR+ASC+G', '-nt', 'AUTO', '-redo', '-quiet'])
    with open('popgen_alignment.fasta.treefile') as fh:
        return fh.read().strip()


def run_mrbayes():
    with open('popgen_mb_run.nex', 'w') as fh:
        fh.write('#NEXUS\n')
        fh.write('execute popgen_alignment.nex;\n')
        fh.write('begin mrbayes;\n')
        fh.write('  set autoclose=yes nowarn=yes;\n')
        fh.write('  lset coding=variable;\n')
        fh.write('  lset nst=6 rates=gamma;\n')
        fh.write('  mcmcp ngen=10000 samplefreq=100 printfreq=100 diagnfreq=500 nchains=4 burninfrac=0.25;\n')
        fh.write('  mcmc;\n')
        fh.write('  sumt;\n')
        fh.write('end;\n')

    run_cmd(['mb', 'popgen_mb_run.nex'])

    tree_line = None
    with open('popgen_alignment.nex.con.tre') as fh:
        for line in fh:
            s = line.strip()
            if s.lower().startswith('tree ') and '=' in s:
                tree_line = s
    if tree_line is None:
        raise RuntimeError('MrBayes did not produce a consensus tree line in popgen_alignment.nex.con.tre')

    newick = tree_line.split('=', 1)[1].strip()
    if newick.startswith('[&U]'):
        newick = newick[len('[&U]'):].strip()
    return newick


def scale(vals, lo, hi):
    vmin = min(vals) if vals else 0.0
    vmax = max(vals) if vals else 1.0
    if math.isclose(vmin, vmax):
        return [0.5 * (lo + hi) for _ in vals]
    return [lo + (v - vmin) * (hi - lo) / (vmax - vmin) for v in vals]


def build_pca_svg(samples, pops, pcs, cmap):
    width, height = 900, 520
    left, right, top, bottom = 70, 620, 40, 470

    pc1 = pcs[:, 0].tolist() if len(samples) else []
    pc2 = pcs[:, 1].tolist() if len(samples) else []
    pc3 = pcs[:, 2].tolist() if len(samples) else []

    x = scale(pc1, left, right)
    y = scale(pc2, bottom, top)
    r = scale(pc3, 5, 13)

    parts = [
        f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' viewBox='0 0 {width} {height}'>",
        "<rect x='0' y='0' width='100%' height='100%' fill='white'/>",
        f"<line x1='{left}' y1='{bottom}' x2='{right}' y2='{bottom}' stroke='#333' stroke-width='1.2'/>",
        f"<line x1='{left}' y1='{bottom}' x2='{left}' y2='{top}' stroke='#333' stroke-width='1.2'/>",
        f"<text x='{(left + right) / 2}' y='{height - 20}' text-anchor='middle' font-size='14'>PC1</text>",
        f"<text x='20' y='{(top + bottom) / 2}' text-anchor='middle' font-size='14' transform='rotate(-90 20 {(top + bottom) / 2})'>PC2</text>",
        "<text x='70' y='20' font-size='14'>Marker radius encodes PC3 magnitude</text>",
    ]

    for i, s in enumerate(samples):
        color = cmap[pops[i]]
        parts.append(
            f"<circle cx='{x[i]:.2f}' cy='{y[i]:.2f}' r='{r[i]:.2f}' fill='{color}' fill-opacity='0.78' stroke='#222' stroke-width='0.6'>"
            f"<title>{s} | pop={pops[i]} | PC1={pc1[i]:.4f} PC2={pc2[i]:.4f} PC3={pc3[i]:.4f}</title></circle>"
        )

    lx, ly = 670, 60
    parts.append(f"<text x='{lx}' y='{ly - 18}' font-size='14'>Population</text>")
    for idx, pop in enumerate(cmap.keys()):
        yy = ly + idx * 22
        parts.append(f"<rect x='{lx}' y='{yy - 10}' width='14' height='14' fill='{cmap[pop]}' stroke='#222' stroke-width='0.5'/>")
        parts.append(f"<text x='{lx + 22}' y='{yy + 1}' font-size='12'>{pop}</text>")

    parts.append("</svg>")
    return ''.join(parts)


def assign_leaf_y(node, out, start=40, step=24):
    if node.is_leaf:
        out[node.name] = start + len(out) * step
        return
    assign_leaf_y(node.left, out, start, step)
    assign_leaf_y(node.right, out, start, step)


def collect_segments(node, leaf_y, max_h, x0=50, x1=820, segs=None):
    if segs is None:
        segs = []

    def x(h):
        if max_h <= 0:
            return x0
        return x0 + (h / max_h) * (x1 - x0)

    if node.is_leaf:
        return x(node.height), leaf_y[node.name], segs

    lx, ly, segs = collect_segments(node.left, leaf_y, max_h, x0, x1, segs)
    rx, ry, segs = collect_segments(node.right, leaf_y, max_h, x0, x1, segs)
    px = x(node.height)

    segs.append((lx, ly, px, ly))
    segs.append((rx, ry, px, ry))
    segs.append((px, min(ly, ry), px, max(ly, ry)))

    return px, (ly + ry) / 2.0, segs


def build_tree_svg(root, pop_map, cmap, tree_method):
    leaves = []

    def get_leaves(n):
        if n.is_leaf:
            leaves.append(n.name)
            return
        get_leaves(n.left)
        get_leaves(n.right)

    get_leaves(root)
    leaf_y = {}
    assign_leaf_y(root, leaf_y, start=40, step=26)
    max_h = root.height if root else 0.0

    width = 950
    height = max(220, 80 + 26 * len(leaves))
    segs = []
    collect_segments(root, leaf_y, max_h, x0=70, x1=760, segs=segs)

    parts = [
        f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' viewBox='0 0 {width} {height}'>",
        "<rect x='0' y='0' width='100%' height='100%' fill='white'/>",
        f"<text x='70' y='22' font-size='14'>{tree_method.upper()} tree built from Euclidean distances over PC1-PC3</text>",
    ]

    for x1, y1, x2, y2 in segs:
        parts.append(f"<line x1='{x1:.2f}' y1='{y1:.2f}' x2='{x2:.2f}' y2='{y2:.2f}' stroke='#333' stroke-width='1.1'/>")

    for s in leaves:
        y = leaf_y[s]
        pop = pop_map.get(s, 'NA')
        c = cmap[pop]
        parts.append(f"<circle cx='770' cy='{y:.2f}' r='4.5' fill='{c}' stroke='#222' stroke-width='0.6'/>")
        parts.append(f"<text x='780' y='{y + 4:.2f}' font-size='12'>{s} ({pop})</text>")

    lx, ly = 70, height - 18 - 22 * len(cmap)
    parts.append(f"<text x='{lx}' y='{ly - 10}' font-size='13'>Population colors</text>")
    for i, pop in enumerate(cmap.keys()):
        yy = ly + i * 20
        parts.append(f"<rect x='{lx}' y='{yy - 10}' width='12' height='12' fill='{cmap[pop]}' stroke='#222' stroke-width='0.5'/>")
        parts.append(f"<text x='{lx + 18}' y='{yy}' font-size='11'>{pop}</text>")

    parts.append("</svg>")
    return ''.join(parts)


def main():
    parser = argparse.ArgumentParser(description='Run population genetics PCA/tree analyses for popfun.')
    parser.add_argument('--vcf', required=True, help='Input cohort VCF.gz path staged by Nextflow')
    parser.add_argument('--samplesheet', required=True, help='Input samplesheet CSV with sample/pop columns')
    parser.add_argument('--tree-method', required=True, choices=['upgma', 'nj', 'ml', 'bayesian'], help='Tree inference mode')
    parser.add_argument('--legend-order', required=True, choices=['samplesheet', 'alphabetical'], help='Legend ordering mode')
    args = parser.parse_args()

    tree_method = args.tree_method.strip().lower()
    legend_order = args.legend_order.strip().lower()

    pop_map, pop_first_seen = read_pop_map(args.samplesheet)

    vcf_path = args.vcf
    if not os.path.exists(vcf_path):
        raise RuntimeError(f'Input VCF was not staged: {vcf_path}')

    vf = pysam.VariantFile(vcf_path)
    samples = list(vf.header.samples)

    if len(samples) == 0:
        raise RuntimeError('Population VCF has no samples in header.')

    rows = []
    for rec in vf:
        d = []
        for s in samples:
            gt = rec.samples[s].get('GT')
            d.append(gt_to_dosage(gt))
        rows.append(d)

    if len(rows) == 0:
        pcs = np.zeros((len(samples), 3), dtype=float)
    else:
        x = np.array(rows, dtype=float).T
        pcs = pca_scores(x, n_comp=3)

    with open('popgen_pca_coords.csv', 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['sample', 'pop', 'PC1', 'PC2', 'PC3'])
        for i, s in enumerate(samples):
            pop = pop_map.get(s, 'NA')
            w.writerow([s, pop, round(float(pcs[i, 0]), 6), round(float(pcs[i, 1]), 6), round(float(pcs[i, 2]), 6)])

    dist = {}
    for i in range(len(samples)):
        for j in range(i + 1, len(samples)):
            dij = float(np.linalg.norm(pcs[i, :3] - pcs[j, :3]))
            dist[(i, j)] = dij

    if len(samples) == 1:
        root = Node(name=samples[0], height=0.0)
        newick = f'{samples[0]};'
    else:
        if tree_method in ('upgma', 'nj'):
            root = upgma(samples, dist) if tree_method == 'upgma' else neighbor_joining(samples, dist)
            newick = to_newick(root)
        else:
            write_alignment_files(vcf_path, samples)
            root = None
            newick = run_iqtree_ml() if tree_method == 'ml' else run_mrbayes()

    with open('popgen_tree.newick', 'w') as fh:
        fh.write(newick + '\n')

    pops = [pop_map.get(s, 'NA') for s in samples]
    legend_pops = ordered_pops(samples, pop_map, pop_first_seen, legend_order)
    cmap = palette_for_pops(legend_pops)
    pca_svg = build_pca_svg(samples, pops, pcs, cmap)
    if root is not None:
        tree_svg = build_tree_svg(root, pop_map, cmap, tree_method)
    else:
        tree_svg = (
            f'<p><b>{tree_method.upper()} tree inference completed.</b></p>'
            '<p>Rendered tree graphics are available in exported outputs; Newick is shown below.</p>'
        )

    pca_html = (
        "# id: 'popgen_pca'\n"
        "# section_name: 'Population Genetics: PCA (PC1-PC3)'\n"
        "# description: 'Principal component analysis from population VCF genotype dosages. Point color uses samplesheet pop column.'\n"
        "# plot_type: 'html'\n"
        + pca_svg + '\n'
    )

    with open('popgen_pca_mqc.txt', 'w') as fh:
        fh.write(pca_html)

    tree_html = (
        "# id: 'popgen_tree'\n"
        "# section_name: 'Population Genetics: Phylogenetic Tree'\n"
        "# description: 'Tree built from Euclidean distances over PCA components (PC1-PC3) using selected method. Leaf colors use samplesheet pop column.'\n"
        "# plot_type: 'html'\n"
        "<p><b>Newick:</b> <code>" + newick.replace('<', '&lt;').replace('>', '&gt;') + "</code></p>\n"
        + tree_svg + '\n'
    )

    with open('popgen_tree_mqc.txt', 'w') as fh:
        fh.write(tree_html)


if __name__ == '__main__':
    main()
