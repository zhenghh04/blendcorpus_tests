#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${BLENDCORPUS_REPO:?Set BLENDCORPUS_REPO to an existing blendcorpus checkout}"

if [[ ! -d "$BLENDCORPUS_REPO" ]]; then
  echo "BLENDCORPUS_REPO does not exist: $BLENDCORPUS_REPO" >&2
  exit 1
fi

export PPN="${PPN:-12}"
export SEQ_LENGTH="${SEQ_LENGTH:-2048}"
export MICRO_BATCH_SIZE="${MICRO_BATCH_SIZE:-4}"
export TRAIN_ITERS="${TRAIN_ITERS:-100}"
export NUM_WORKERS="${NUM_WORKERS:-2}"
export NUM_CORPORA="${NUM_CORPORA:-4}"
export NUM_FILES_PER_CORPUS="${NUM_FILES_PER_CORPUS:-8}"
export NUM_DOCS="${NUM_DOCS:-524032}"
export WORK_ROOT="${WORK_ROOT:-$PWD/blendcorpus_aurora_smoke}"
export TRACE_DIR="${TRACE_DIR:-$WORK_ROOT/trace}"
export FIXTURE_DIR="${FIXTURE_DIR:-$WORK_ROOT/testdata}"
export MPIEXEC_BIN="${MPIEXEC_BIN:-mpiexec}"
if [[ -z "${MPIEXEC_ARGS+x}" ]]; then
  export MPIEXEC_ARGS="--ppn $PPN --cpu-bind depth -d 1"
fi

if [[ -n "${PBS_NODEFILE:-}" && -f "${PBS_NODEFILE}" ]]; then
  NNODES=$(sort -u "$PBS_NODEFILE" | wc -l | tr -d ' ')
else
  NNODES=1
fi

export FIXTURE_MPI_RANKS="${FIXTURE_MPI_RANKS:-$((NNODES * PPN))}"

# Using MPI to create the dataset in parallel, 1 rank per node 
mpiexec -n $NNODES --ppn 1  \
    python3 "$SCRIPT_DIR/create_dataset.py" \
      --output-dir "$FIXTURE_DIR" \
      --num-corpora "$NUM_CORPORA" \
      --num-files-per-corpus "$NUM_FILES_PER_CORPUS" \
      --seq-length "$SEQ_LENGTH" \
      --num-docs "$NUM_DOCS"

make -C "$BLENDCORPUS_REPO/blendcorpus/data"

mkdir -p "$TRACE_DIR"

NRANKS=$((NNODES * PPN))
export GLOBAL_BATCH_SIZE="${GLOBAL_BATCH_SIZE:-$((MICRO_BATCH_SIZE * NRANKS))}"

mpiexec -n "$NRANKS" $MPIEXEC_ARGS \
  "$BLENDCORPUS_REPO/utils/launcher.sh" \
  python3 "$BLENDCORPUS_REPO/tests/test_dataloader.py" \
    --trace-dir "$TRACE_DIR" \
    --data-file-list "$FIXTURE_DIR/tiny_file_list.txt" \
    --global-batch-size "$GLOBAL_BATCH_SIZE" \
    --train-iters "$TRAIN_ITERS" \
    --seq-length "$SEQ_LENGTH" \
    --micro-batch-size "$MICRO_BATCH_SIZE" \
    --num-workers "$NUM_WORKERS" \
    --dataloader-iter
