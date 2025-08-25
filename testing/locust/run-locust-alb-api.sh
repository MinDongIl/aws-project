#!/usr/bin/env bash
set -euo pipefail

: "${ALB_DNS:?set ALB_DNS}"
USERS="${USERS:-800}"
SPAWN_RATE="${SPAWN_RATE:-80}"
RUN_TIME="${RUN_TIME:-10m}"
CSV_PREFIX="${CSV_PREFIX:-out/locust_alb_$(date +%Y%m%d_%H%M%S)}"

mkdir -p out

VENV=".venv"
PY="${VENV}/bin/python"
[ -x "${VENV}/Scripts/python" ] && PY="${VENV}/Scripts/python"

"$PY" -m pip install --quiet --upgrade "locust>=2.20,<3.0"

"$PY" -m locust -f testing/locust/locustfile_alb_api.py \
  --headless -u "${USERS}" -r "${SPAWN_RATE}" -t "${RUN_TIME}" \
  --host "http://${ALB_DNS}" \
  --csv "${CSV_PREFIX}" --csv-full-history \
  --only-summary --stop-timeout 30
