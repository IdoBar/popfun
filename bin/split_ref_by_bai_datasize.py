#!/usr/bin/env python3

"""Split a reference into regions with approximately equal BAI-backed data size.

This is a stdlib-only implementation compatible with the interface of the
upstream freebayes `split_ref_by_bai_datasize.py` helper. It reads one or more
BAI indexes, estimates cumulative data size across fixed BAI intervals, and
emits tab-separated `chrom start end` regions.
"""

from __future__ import annotations

import argparse
import bisect
import math
import os
import struct
import sys
from typing import List, Sequence, Tuple


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bamfiles", metavar="BAMFILE", nargs="*")
    parser.add_argument("-L", "--bam-list", nargs="*")
    parser.add_argument("-r", "--reference-fai", required=True)
    parser.add_argument(
        "-s",
        "--target-data-size",
        default="100000000",
        help="Target cumulative BAI data size per region in bytes.",
    )
    parser.add_argument(
        "--bai-interval-size",
        default=16384,
        type=int,
        help="Number of bases represented by each linear BAI interval.",
    )
    return parser.parse_args(argv)


def load_bamfiles(args: argparse.Namespace) -> List[str]:
    bamfiles = list(args.bamfiles)
    for bam_list_file in args.bam_list or []:
        with open(bam_list_file, "r", encoding="utf-8") as handle:
            for line in handle:
                entry = line.split("#", 1)[0].strip()
                if entry:
                    bamfiles.append(entry)
    if not bamfiles:
        raise SystemExit("Must provide at least one BAM file or --bam-list")
    return bamfiles


def read_fai(fai_path: str) -> Tuple[List[str], List[int]]:
    chroms: List[str] = []
    lengths: List[int] = []
    with open(fai_path, "r", encoding="utf-8") as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            chroms.append(fields[0])
            lengths.append(int(fields[1]))
    return chroms, lengths


def read_exact(handle, size: int) -> bytes:
    data = handle.read(size)
    if len(data) != size:
        raise EOFError("Unexpected end of BAI file")
    return data


def read_i32(handle) -> int:
    return struct.unpack("i", read_exact(handle, 4))[0]


def read_u32(handle) -> int:
    return struct.unpack("I", read_exact(handle, 4))[0]


def resolve_bai_path(bam_path: str) -> str:
    candidates = [f"{bam_path}.bai"]
    if bam_path.endswith(".bam"):
        candidates.append(f"{bam_path[:-4]}.bai")
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    raise FileNotFoundError(f"No BAI found for BAM: {bam_path}")


def add_bai_offsets(
    bai_path: str,
    chrom_lengths: Sequence[int],
    bai_interval_size: int,
    cumulative_sizes: List[List[int]],
) -> None:
    expected_intervals = [int(math.ceil(length / bai_interval_size)) for length in chrom_lengths]

    with open(bai_path, "rb") as handle:
        if struct.unpack("4s", read_exact(handle, 4))[0] != b"BAI\x01":
            raise ValueError(f"Invalid BAI header for {bai_path}")

        n_ref = read_i32(handle)
        if n_ref != len(chrom_lengths):
            raise ValueError("FAI and BAI reference counts do not match")

        for chrom_index in range(n_ref):
            n_bin = read_i32(handle)
            for _ in range(n_bin):
                _ = read_u32(handle)
                n_chunk = read_i32(handle)
                handle.seek(n_chunk * 16, os.SEEK_CUR)

            n_intv = read_i32(handle)
            if n_intv <= 0:
                continue

            offsets = list(struct.unpack(f"{n_intv}Q", read_exact(handle, n_intv * 8)))
            if not offsets:
                continue

            while len(offsets) < expected_intervals[chrom_index]:
                offsets.append(offsets[-1] + 1)

            normalized = [value - offsets[0] for value in offsets[: expected_intervals[chrom_index]]]
            cumulative_sizes[chrom_index] = [
                left + right for left, right in zip(cumulative_sizes[chrom_index], normalized)
            ]


def interp(xs: Sequence[int], ys: Sequence[int], x_value: int) -> float:
    if len(xs) == 1:
        return float(ys[0])

    if x_value <= xs[0]:
        left, right = 0, 1
    elif x_value >= xs[-1]:
        left, right = len(xs) - 2, len(xs) - 1
    else:
        right = bisect.bisect_right(xs, x_value)
        left = right - 1

    x0, x1 = xs[left], xs[right]
    y0, y1 = ys[left], ys[right]
    if x1 == x0:
        return float(y0)
    return y0 + ((x_value - x0) * (y1 - y0) / float(x1 - x0))


def inverse_interp(ys: Sequence[int], xs: Sequence[int], y_value: int) -> float:
    if len(ys) == 1:
        return float(xs[0])

    if y_value <= ys[0]:
        left, right = 0, 1
    elif y_value >= ys[-1]:
        left, right = len(ys) - 2, len(ys) - 1
    else:
        right = bisect.bisect_right(ys, y_value)
        left = right - 1

    while right < len(ys) and ys[right] == ys[left]:
        right += 1
    if right >= len(ys):
        return float(xs[left])

    y0, y1 = ys[left], ys[right]
    x0, x1 = xs[left], xs[right]
    if y1 == y0:
        return float(x0)
    return x0 + ((y_value - y0) * (x1 - x0) / float(y1 - y0))


def build_regions(
    chroms: Sequence[str],
    lengths: Sequence[int],
    cumulative_sizes: Sequence[Sequence[int]],
    bai_interval_size: int,
    target_data_size: int,
) -> List[Tuple[str, int, int]]:
    regions: List[Tuple[str, int, int]] = []

    for chrom, chrom_length, data_sizes in zip(chroms, lengths, cumulative_sizes):
        if len(data_sizes) < 2:
            regions.append((chrom, 0, chrom_length))
            continue

        positions = [index * bai_interval_size for index in range(len(data_sizes))]
        total_data_size = int(round(interp(positions, data_sizes, chrom_length)))
        n_regions = max(1, int(math.ceil(total_data_size / float(target_data_size))))

        boundaries = [0]
        for region_index in range(1, n_regions):
            target = int(round(region_index * total_data_size / float(n_regions)))
            boundary = int(round(inverse_interp(data_sizes, positions, target)))
            boundary = max(boundaries[-1], min(chrom_length, boundary))
            boundaries.append(boundary)
        boundaries.append(chrom_length)

        normalized_boundaries = [boundaries[0]]
        for boundary in boundaries[1:]:
            if boundary > normalized_boundaries[-1]:
                normalized_boundaries.append(boundary)
        if normalized_boundaries[-1] != chrom_length:
            normalized_boundaries.append(chrom_length)

        for start, end in zip(normalized_boundaries, normalized_boundaries[1:]):
            if end > start:
                regions.append((chrom, start, end))

    return regions


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    bamfiles = load_bamfiles(args)
    target_data_size = int(float(args.target_data_size))
    if target_data_size < 1:
        raise SystemExit("--target-data-size must be >= 1")

    chroms, lengths = read_fai(args.reference_fai)
    cumulative_sizes = [
        [0] * int(math.ceil(length / args.bai_interval_size)) for length in lengths
    ]

    for bam_path in bamfiles:
        add_bai_offsets(
            resolve_bai_path(bam_path),
            lengths,
            args.bai_interval_size,
            cumulative_sizes,
        )

    for chrom, start, end in build_regions(
        chroms,
        lengths,
        cumulative_sizes,
        args.bai_interval_size,
        target_data_size,
    ):
        print(chrom, start, end, sep="\t")

    return 0


if __name__ == "__main__":
    sys.exit(main())