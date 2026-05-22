#!/usr/bin/env python3

import gzip
import sys
from collections import defaultdict


def open_text(path):
    return gzip.open(path, "rt", encoding="utf-8") if path.endswith(".gz") else open(path, encoding="utf-8")


if len(sys.argv) < 3:
    print("usage: {} ref.fai sample1.per-base.bed.gz [sample2.per-base.bed.gz ...]".format(sys.argv[0]), file=sys.stderr)
    raise SystemExit(1)

chrom_order = []
with open(sys.argv[1], encoding="utf-8") as fai_handle:
    for line in fai_handle:
        chrom = line.split("\t", 1)[0]
        chrom_order.append(chrom)

events = defaultdict(lambda: defaultdict(int))

for path in sys.argv[2:]:
    with open_text(path) as handle:
        for raw_line in handle:
            fields = raw_line.rstrip("\n").split("\t")
            if len(fields) < 4:
                continue
            chrom, start, end, depth = fields[:4]
            depth_value = int(float(depth))
            if depth_value <= 0:
                continue
            start_pos = int(start) + 1
            end_pos = int(end)
            events[chrom][start_pos] += depth_value
            events[chrom][end_pos + 1] -= depth_value

for chrom in chrom_order:
    chrom_events = events.get(chrom)
    if not chrom_events:
        continue
    current_depth = 0
    previous_position = None
    for position in sorted(chrom_events):
        if previous_position is not None and current_depth > 0 and previous_position < position:
            for base_position in range(previous_position, position):
                print(f"{chrom}\t{base_position}\t{current_depth}")
        current_depth += chrom_events[position]
        previous_position = position