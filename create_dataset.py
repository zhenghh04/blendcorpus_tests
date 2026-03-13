#!/usr/bin/env python3
"""Create blendcorpus smoke-test datasets in serial or with mpi4py."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

import numpy as np


DTYPE_CODE = 4  # np.int32 in blendcorpus.data.indexed_dataset.dtypes
HDR_MAGIC = b"MMIDIDX\x00\x00"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("blendcorpus_aurora_smoke/testdata"),
        help="Directory where the fixture and file list will be written.",
    )
    parser.add_argument("--prefix", default="tiny_text")
    parser.add_argument("--corpus-name", default="synthetic")
    parser.add_argument("--num-corpora", type=int, default=1)
    parser.add_argument("--num-files-per-corpus", type=int, default=1)
    parser.add_argument("--num-docs", type=int, default=524032)
    parser.add_argument("--seq-length", type=int, default=2048)
    parser.add_argument(
        "--mpi",
        action="store_true",
        help="Distribute file generation across MPI ranks and have rank 0 write the file list.",
    )
    return parser.parse_args()


def write_mmap_dataset_streaming(prefix: Path, num_docs: int, seq_length: int) -> None:
    prefix.parent.mkdir(parents=True, exist_ok=True)
    bin_path = prefix.with_suffix(".bin")
    idx_path = prefix.with_suffix(".idx")

    doc_size = seq_length + 1
    sizes = np.full(num_docs, doc_size, dtype=np.int32)
    pointers = np.arange(num_docs, dtype=np.int64) * doc_size * np.dtype(np.int32).itemsize
    doc_idx = np.arange(num_docs + 1, dtype=np.int64)

    with open(bin_path, "wb") as fout:
        for doc_id in range(num_docs):
            start = 1000 * (doc_id + 1)
            doc = np.arange(start, start + doc_size, dtype=np.int32)
            fout.write(doc.tobytes(order="C"))

    with open(idx_path, "wb") as fout:
        fout.write(HDR_MAGIC)
        fout.write(struct.pack("<Q", 1))
        fout.write(struct.pack("<B", DTYPE_CODE))
        fout.write(struct.pack("<Q", num_docs))
        fout.write(struct.pack("<Q", len(doc_idx)))
        fout.write(sizes.tobytes(order="C"))
        fout.write(pointers.tobytes(order="C"))
        fout.write(doc_idx.tobytes(order="C"))


def build_tasks(num_corpora: int, num_files_per_corpus: int) -> list[tuple[int, int]]:
    return [
        (corpus_idx, file_idx)
        for corpus_idx in range(num_corpora)
        for file_idx in range(num_files_per_corpus)
    ]


def build_line(output_dir: Path, prefix: str, corpus_name: str, corpus_idx: int, file_idx: int) -> tuple[int, int, str]:
    dataset_prefix = output_dir / f"{prefix}_{corpus_idx:02d}_{file_idx:02d}"
    return corpus_idx, file_idx, f"1.0 {dataset_prefix} {corpus_name}\n"


def generate_one_file(
    output_dir: Path,
    prefix_base: str,
    corpus_name_base: str,
    corpus_idx: int,
    file_idx: int,
    num_docs: int,
    seq_length: int,
    rank_label: str | None = None,
) -> tuple[int, int, str]:
    corpus_name = f"{corpus_name_base}_{corpus_idx:02d}"
    dataset_prefix = output_dir / f"{prefix_base}_{corpus_idx:02d}_{file_idx:02d}"
    write_mmap_dataset_streaming(dataset_prefix, num_docs, seq_length)
    if rank_label is None:
        print(f"Wrote dataset prefix: {dataset_prefix}", flush=True)
    else:
        print(f"[rank {rank_label}] wrote dataset prefix: {dataset_prefix}", flush=True)
    return build_line(output_dir, prefix_base, corpus_name, corpus_idx, file_idx)


def write_file_list(output_dir: Path, entries: list[tuple[int, int, str]]) -> Path:
    entries.sort(key=lambda item: (item[0], item[1]))
    file_list = output_dir / "tiny_file_list.txt"
    file_list.write_text("".join(line for _, _, line in entries), encoding="utf-8")
    print(f"Wrote file list: {file_list}", flush=True)
    return file_list


def run_serial(args: argparse.Namespace) -> None:
    entries = []
    for corpus_idx, file_idx in build_tasks(args.num_corpora, args.num_files_per_corpus):
        entries.append(
            generate_one_file(
                output_dir=args.output_dir,
                prefix_base=args.prefix,
                corpus_name_base=args.corpus_name,
                corpus_idx=corpus_idx,
                file_idx=file_idx,
                num_docs=args.num_docs,
                seq_length=args.seq_length,
            )
        )
    write_file_list(args.output_dir, entries)


def run_mpi(args: argparse.Namespace) -> None:
    from mpi4py import MPI

    comm = MPI.COMM_WORLD
    rank = comm.rank
    size = comm.size

    local_entries = []
    for corpus_idx, file_idx in build_tasks(args.num_corpora, args.num_files_per_corpus)[rank::size]:
        local_entries.append(
            generate_one_file(
                output_dir=args.output_dir,
                prefix_base=args.prefix,
                corpus_name_base=args.corpus_name,
                corpus_idx=corpus_idx,
                file_idx=file_idx,
                num_docs=args.num_docs,
                seq_length=args.seq_length,
                rank_label=str(rank),
            )
        )

    gathered = comm.gather(local_entries, root=0)
    if rank == 0:
        merged = []
        for chunk in gathered:
            merged.extend(chunk)
        write_file_list(args.output_dir, merged)


def main() -> None:
    args = parse_args()
    args.output_dir = args.output_dir.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    if args.mpi:
        run_mpi(args)
    else:
        run_serial(args)


if __name__ == "__main__":
    main()
