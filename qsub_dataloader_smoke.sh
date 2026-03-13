#!/bin/bash
#PBS -l select=4:ncpus=208
#PBS -l walltime=00:30:00
#PBS -N blendcorpus_smoke
#PBS -l filesystems=home:flare
#PBS -A datascience
#PBS -j oe

set -euo pipefail

cd $PBS_O_WORKDIR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

module load frameworks

if [[ -n "${BLENDCORPUS_VENV:-}" ]]; then
  set +u
  source "${BLENDCORPUS_VENV}/bin/activate"
  set -u
fi

bash "$SCRIPT_DIR/run_dataloader_smoke.sh"
