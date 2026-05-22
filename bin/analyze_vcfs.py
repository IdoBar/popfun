import gzip
import sys

def extract_variants(filename):
    variants = {}
    total_lines = 0
    print(f"Reading {filename}...", file=sys.stderr)
    try:
        with gzip.open(filename, 'rt') as f:
            for line in f:
                if line.startswith('#'):
                    continue
                total_lines += 1
                parts = line.split('\t')
                if len(parts) < 5:
                    continue
                chrom = parts[0]
                pos = int(parts[1])
                ref = parts[3]
                alt = parts[4]
                variant_id = f"{chrom}:{pos}:{ref}:{alt}"
                if chrom not in variants:
                    variants[chrom] = []
                variants[chrom].append((pos, ref, alt, variant_id))
    except Exception as e:
        print(f"Error reading {filename}: {e}", file=sys.stderr)
    print(f"Finished reading {filename}, {total_lines} variants.", file=sys.stderr)
    return variants

gatk_file = "/mnt/d/sandbox/popfun_ensemble_files/joint_called.vcf.gz"
freebayes_file = "/mnt/d/sandbox/popfun_ensemble_files/population.vcf.gz"

gatk_variants_by_chrom = extract_variants(gatk_file)
freebayes_variants_by_chrom = extract_variants(freebayes_file)

gatk_ids = set()
for chrom in gatk_variants_by_chrom:
    for v in gatk_variants_by_chrom[chrom]:
        gatk_ids.add(v[3])

fb_ids = set()
for chrom in freebayes_variants_by_chrom:
    for v in freebayes_variants_by_chrom[chrom]:
        fb_ids.add(v[3])

exact_matches = gatk_ids.intersection(fb_ids)
only_gatk = gatk_ids - fb_ids
only_fb = fb_ids - gatk_ids

print(f"Total GATK variants: {len(gatk_ids)}")
print(f"Total Freebayes variants: {len(fb_ids)}")
print(f"Exact coordinate matches: {len(exact_matches)}")
if gatk_ids:
    print(f"Overlap vs GATK: {len(exact_matches)/len(gatk_ids)*100:.2f}%")
if fb_ids:
    print(f"Overlap vs Freebayes: {len(exact_matches)/len(fb_ids)*100:.2f}%")

shifted_matches = 0
for chrom in gatk_variants_by_chrom:
    if chrom in freebayes_variants_by_chrom:
        fb_pos_map = {}
        for pos, ref, alt, vid in freebayes_variants_by_chrom[chrom]:
            if pos not in fb_pos_map: fb_pos_map[pos] = []
            fb_pos_map[pos].append((ref, alt, vid))
            
        for g_pos, g_ref, g_alt, g_vid in gatk_variants_by_chrom[chrom]:
            if g_vid in exact_matches:
                continue
            found = False
            for offset in range(-5, 6):
                if offset == 0: continue
                if (g_pos + offset) in fb_pos_map:
                    shifted_matches += 1
                    found = True
                    break
print(f"Position-shifted matches (+/- 5bp): {shifted_matches}")

print("\nSample GATK-only:")
for vid in list(only_gatk)[:5]: print(f"  {vid}")
print("\nSample FB-only:")
for vid in list(only_fb)[:5]: print(f"  {vid}")
