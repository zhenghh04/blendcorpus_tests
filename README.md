# BlendCorpus Test Harness

This setup lives outside the `blendcorpus` repository so the project source stays unchanged.

## What it does

It drives an existing `blendcorpus` checkout by:

- generating a synthetic mmap dataset,
- generating those fixtures with `mpi4py`,
- building `blendcorpus/data/helpers`,
- running `tests/test_dataloader.py` through `utils/launcher.sh`,
- writing perf traces into a separate working directory.

The current default is sized so each generated `.bin` file is about 4 GiB at
`SEQ_LENGTH=2048`, which corresponds to `NUM_DOCS=524032`.

For the dataloader test, `GLOBAL_BATCH_SIZE` defaults to
`MICRO_BATCH_SIZE * NRANKS`.

Dataset creation is handled by a single entrypoint:

- `create_dataset.py`

## Quick Start

If you want this directory to prepare its own checkout and virtual environment:

```bash
bash /path/to/blendcorpus_tests/setup.sh
```

That script:

- clones `https://github.com/saforem2/blendcorpus.git` into `./blendcorpus`
- creates `./venv`
- activates it
- installs `blendcorpus` editable into that environment

The shell wrappers temporarily disable `set -u` while activating the virtual
environment so activation scripts do not fail on unset shell-specific variables
such as `ZSH_EVAL_CONTEXT`.

It requires Python 3.8 or newer. If `python3` on your system is older, set a
newer interpreter explicitly:

```bash
PYTHON_BIN=python3.10 bash /path/to/blendcorpus_tests/setup.sh
```

Afterward:

```bash
source /path/to/blendcorpus_tests/venv/bin/activate
export BLENDCORPUS_REPO=/path/to/blendcorpus_tests/blendcorpus
export BLENDCORPUS_VENV=/path/to/blendcorpus_tests/venv
```

## Required Environment

Set the repo path before running:

```bash
export BLENDCORPUS_REPO=/path/to/blendcorpus
```

If you have a dedicated virtual environment, activate it or pass:

```bash
export BLENDCORPUS_VENV=/path/to/.venv
```

## Setup Files

- [setup.sh](./setup.sh): clone repo, create `venv`, install `blendcorpus`
- [create_dataset.py](./create_dataset.py): generate synthetic dataset files and `tiny_file_list.txt`
- [run_dataloader_smoke.sh](./run_dataloader_smoke.sh): generate fixtures, build helper extension, run dataloader test
- [qsub_dataloader_smoke.sh](./qsub_dataloader_smoke.sh): PBS wrapper for Aurora

## Submit on Aurora

Use your project explicitly at submit time:

```bash
qsub -A <project> /path/to/blendcorpus_tests/qsub_dataloader_smoke.sh
```

The PBS wrapper loads `frameworks`, activates `BLENDCORPUS_VENV` when set, and
then runs the external launcher.

The launcher also exports `PYTHONPATH=$BLENDCORPUS_REPO` before starting the MPI
test ranks so `blendcorpus` is importable even when editable-install metadata is
not picked up cleanly by `mpiexec`.

## Run Inside an Existing Allocation

```bash
export BLENDCORPUS_REPO=/path/to/blendcorpus
bash /path/to/blendcorpus_tests/run_dataloader_smoke.sh
```

## Defaults

- `PPN=12`
- `SEQ_LENGTH=2048`
- `MICRO_BATCH_SIZE=4`
- `TRAIN_ITERS=100`
- `NUM_WORKERS=2`
- `NUM_CORPORA=4`
- `NUM_FILES_PER_CORPUS=8`
- `NUM_DOCS=524032`
- `GLOBAL_BATCH_SIZE=MICRO_BATCH_SIZE * NRANKS`

## Useful Overrides

```bash
PPN=2 TRAIN_ITERS=8 MICRO_BATCH_SIZE=4 SEQ_LENGTH=2048 NUM_CORPORA=2 NUM_FILES_PER_CORPUS=1 \
WORK_ROOT=$PWD/blendcorpus_aurora_smoke \
bash /path/to/blendcorpus_tests/run_dataloader_smoke.sh
```

The launcher always generates the `.bin/.idx` fixtures with MPI using one rank
per node:

```bash
mpiexec -n $NNODES --ppn 1 python3 ./create_dataset.py --output-dir ...
```

For MPI launchers that do not support Aurora-specific flags such as `--ppn` or
`--cpu-bind`, override them explicitly:

```bash
MPIEXEC_ARGS="" bash /path/to/blendcorpus_tests/run_dataloader_smoke.sh
```

If you want to override the computed global batch size explicitly:

```bash
GLOBAL_BATCH_SIZE=32 bash /path/to/blendcorpus_tests/run_dataloader_smoke.sh
```

## Outputs

The external setup writes:

- `testdata/tiny_text_00_00.bin`
- `testdata/tiny_text_00_00.idx`
- additional `tiny_text_<corpus>_<file>.bin/.idx` files when `NUM_CORPORA > 1` or `NUM_FILES_PER_CORPUS > 1`
- `testdata/tiny_file_list.txt`
- `trace/trace-<rank>-of-<world>.pfw`

under `${WORK_ROOT}`, which defaults to `./blendcorpus_aurora_smoke`.
