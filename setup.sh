#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_URL="${REPO_URL:-https://github.com/saforem2/blendcorpus.git}"
REPO_DIR="${REPO_DIR:-$SCRIPT_DIR/blendcorpus}"
VENV_DIR="$SCRIPT_DIR/venv"

if [[ -d "$REPO_DIR/.git" ]]; then
  echo "Using existing repository: $REPO_DIR"
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip
python -m pip install -e "$REPO_DIR"

cat <<EOF
Setup complete.

To use this environment:
  source "$VENV_DIR/bin/activate"

Suggested exports:
  export BLENDCORPUS_REPO="$REPO_DIR"
  export BLENDCORPUS_VENV="$VENV_DIR"
EOF
