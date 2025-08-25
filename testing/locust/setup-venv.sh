#!/usr/bin/env bash
set -euo pipefail

VENV_DIR=".venv"
PY_WIN="${VENV_DIR}/Scripts/python"
PY_NIX="${VENV_DIR}/bin/python"

if [ ! -d "$VENV_DIR" ]; then
  python -m venv "$VENV_DIR" || py -m venv "$VENV_DIR"
fi

PY="$PY_NIX"
[ -x "$PY_WIN" ] && PY="$PY_WIN"

"$PY" -m pip install --upgrade pip
"$PY" -m pip install "locust>=2.20,<3.0"

echo "[OK] Locust installed"
"$PY" -c "import sys; import locust; print('python:', sys.version.split()[0]); print('locust:', locust.__version__)"
