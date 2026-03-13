#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_URL="${REPO_URL:-https://github.com/saforem2/blendcorpus.git}"
REPO_DIR="${REPO_DIR:-$SCRIPT_DIR/blendcorpus}"
VENV_DIR="$SCRIPT_DIR/venv"
PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$PYTHON_BIN" ]]; then
  for candidate in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "No suitable Python interpreter found." >&2
  exit 1
fi

PY_VERSION=$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)'; then
  echo "Python $PY_VERSION is too old. Use Python 3.8+ (3.10+ recommended)." >&2
  echo "Set PYTHON_BIN explicitly, for example: PYTHON_BIN=python3.10 bash setup.sh" >&2
  exit 1
fi

if [[ -d "$REPO_DIR/.git" ]]; then
  echo "Using existing repository: $REPO_DIR"
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

"$PYTHON_BIN" -m venv "$VENV_DIR"
set +u
source "$VENV_DIR/bin/activate"
set -u

python -m pip install --upgrade pip
python -m pip install -e "$REPO_DIR"

cat <<EOF
Setup complete.

To use this environment:
  source "$VENV_DIR/bin/activate"

Suggested exports:
  export PYTHON_BIN="$PYTHON_BIN"
  export BLENDCORPUS_REPO="$REPO_DIR"
  export BLENDCORPUS_VENV="$VENV_DIR"
EOF
