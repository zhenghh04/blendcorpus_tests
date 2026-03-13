#!/bin/bash
#PBS -l select=1:ncpus=208
#PBS -l walltime=00:10:00
#PBS -N blendcorpus_smoke
#PBS -l filesystems=home:flare
#PBS -j oe

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

module load frameworks

if [[ -n "${BLENDCORPUS_VENV:-}" ]]; then
  source "${BLENDCORPUS_VENV}/bin/activate"
fi

# Keep fixture generation MPI-first unless explicitly disabled by the caller.
export GENERATE_FIXTURE_WITH_MPI="${GENERATE_FIXTURE_WITH_MPI:-1}"

bash "$SCRIPT_DIR/run_dataloader_smoke.sh"
