#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${RUN_ID:-run-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="testing/results/${RUN_ID}"
mkdir -p "$OUT_DIR"

: "${TARGET_BASE_URL:?set TARGET_BASE_URL (e.g. https://traffic.nextcloudlab.com)}"

# Pick Python
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
elif command -v py >/dev/null 2>&1; then PY="py -3"
else echo "[ERROR] Python3 not found in PATH"; exit 1
fi

# venv
VENV_DIR=".venv"
if [[ "${OS:-}" == "Windows_NT" || "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
  VENV_PY="$VENV_DIR/Scripts/python.exe"
else
  VENV_PY="$VENV_DIR/bin/python"
fi
if [[ ! -x "$VENV_PY" ]]; then
  echo "[INFO] Creating venv at $VENV_DIR"
  $PY -m venv "$VENV_DIR"
  "$VENV_PY" -m pip install --upgrade pip
  "$VENV_PY" -m pip install -r "testing/locust/requirements.txt"
fi

# Paths (use defaults if empty; must match locustfile.py)
PATH_DEFAULT="${PATH_DEFAULT:-/}"
PATH_CACHEOBJ="${PATH_CACHEOBJ:-/index.html}"
PATH_STATUS="${PATH_STATUS:-/}"
PATH_PROFILE="${PATH_PROFILE:-/}"

# Quick preflight: require 2xx/3xx on PATH_DEFAULT
code="$(
  curl -sS -o /dev/null -w "%{http_code}" "${TARGET_BASE_URL}${PATH_DEFAULT}" || echo 000
)"
case "$code" in
  200|201|202|204|301|302|304) ;;
  *) echo "[FAIL] ${TARGET_BASE_URL}${PATH_DEFAULT} -> HTTP $code"; exit 1 ;;
esac

echo "[INFO] Host: $TARGET_BASE_URL"
echo "[INFO] Paths: DEFAULT=$PATH_DEFAULT CACHEOBJ=$PATH_CACHEOBJ STATUS=$PATH_STATUS PROFILE=$PATH_PROFILE"
echo "[INFO] RUN_ID=$RUN_ID  CSV_OUT=$OUT_DIR"

# Run-time (shape가 총 길이를 관리하므로 문자열로 넘김, 없으면 20m)
RUN_TIME="${RUN_TIME:-20m}"

"$VENV_PY" -m locust \
  -f testing/locust/locustfile.py \
  --headless \
  --host "$TARGET_BASE_URL" \
  --csv "$OUT_DIR/${RUN_ID}" \
  --csv-full-history \
  --run-time "$RUN_TIME"
