# BlendCorpus Aurora Smoke Test

This setup lives outside the `blendcorpus` repository so the project source stays unchanged.

## What it does

It drives an existing `blendcorpus` checkout on Aurora by:

- generating a tiny synthetic mmap dataset,
- generating those fixtures in parallel with `mpi4py` by default,
- building `blendcorpus/data/helpers`,
- running `tests/test_dataloader.py` through `utils/launcher.sh`,
- writing perf traces into a separate working directory.

The current default is sized so each generated `.bin` file is about 4 GiB at
`SEQ_LENGTH=2048`, which corresponds to `NUM_DOCS=524032`.

For the dataloader test, `GLOBAL_BATCH_SIZE` defaults to
`MICRO_BATCH_SIZE * NRANKS`.

Dataset creation is handled by a single entrypoint:

- `create_dataset.py --mpi` for MPI-distributed generation by default
- `create_dataset.py` for explicit serial fallback

## Quick Start

If you want this directory to prepare its own checkout and virtual environment:

```bash
bash /path/to/blendcorpus_aurora_setup/setup.sh
```

That script:

- clones `https://github.com/zhenghh04/blendcorpus.git` into `./blendcorpus`
- creates `./venv`
- activates it
- installs `blendcorpus` editable into that environment

Afterward:

```bash
source /path/to/blendcorpus_aurora_setup/venv/bin/activate
export BLENDCORPUS_REPO=/path/to/blendcorpus_aurora_setup/blendcorpus
export BLENDCORPUS_VENV=/path/to/blendcorpus_aurora_setup/venv
```

## Required Environment

Set the repo path before running:

```bash
export BLENDCORPUS_REPO=/path/to/blendcorpus
```

If you have a dedicated virtual environment on Aurora, activate it or pass:

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
qsub -A <project> /path/to/blendcorpus_aurora_setup/qsub_dataloader_smoke.sh
```

The PBS wrapper loads `frameworks`, keeps MPI fixture generation enabled by
default, and then runs the external launcher.

## Run Inside an Existing Allocation

```bash
export BLENDCORPUS_REPO=/path/to/blendcorpus
bash /path/to/blendcorpus_aurora_setup/run_dataloader_smoke.sh
```

## Defaults

- `SEQ_LENGTH=2048`
- `NUM_DOCS=524032`
- `NUM_CORPORA=1`
- `NUM_FILES_PER_CORPUS=1`
- `MICRO_BATCH_SIZE=4`
- `GLOBAL_BATCH_SIZE=MICRO_BATCH_SIZE * NRANKS`
- `GENERATE_FIXTURE_WITH_MPI=1`

## Useful Overrides

```bash
PPN=2 TRAIN_ITERS=8 MICRO_BATCH_SIZE=4 SEQ_LENGTH=2048 NUM_CORPORA=2 NUM_FILES_PER_CORPUS=1 \
WORK_ROOT=$PWD/blendcorpus_aurora_smoke \
bash /path/to/blendcorpus_aurora_setup/run_dataloader_smoke.sh
```

By default the `.bin/.idx` fixtures are generated with MPI first. You can set
the fixture rank count explicitly:

```bash
FIXTURE_MPI_RANKS=4 \
bash /path/to/blendcorpus_aurora_setup/run_dataloader_smoke.sh
```

Set `GENERATE_FIXTURE_WITH_MPI=0` if you want the serial fallback instead.

The MPI fixture generation reuses `MPIEXEC_ARGS` by default. Override
`FIXTURE_MPI_ARGS` separately if you want different launcher flags for the
generation phase.

For MPI launchers that do not support Aurora-specific flags such as `--ppn` or
`--cpu-bind`, override them explicitly:

```bash
MPIEXEC_ARGS="" bash /path/to/blendcorpus_aurora_setup/run_dataloader_smoke.sh
```

If you want to override the computed global batch size explicitly:

```bash
GLOBAL_BATCH_SIZE=32 bash /path/to/blendcorpus_aurora_setup/run_dataloader_smoke.sh
```

## Outputs

The external setup writes:

- `testdata/tiny_text_00_00.bin`
- `testdata/tiny_text_00_00.idx`
- additional `tiny_text_<corpus>_<file>.bin/.idx` files when `NUM_CORPORA > 1` or `NUM_FILES_PER_CORPUS > 1`
- `testdata/tiny_file_list.txt`
- `trace/trace-<rank>-of-<world>.pfw`

under `${WORK_ROOT}`, which defaults to `./blendcorpus_aurora_smoke`.
