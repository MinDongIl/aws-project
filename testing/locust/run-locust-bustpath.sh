#!/usr/bin/env bash
set -euo pipefail

: "${CF_DOMAIN:?Set CF_DOMAIN, e.g., traffic.nextcloudlab.com}"
USERS="${USERS:-400}"
SPAWN_RATE="${SPAWN_RATE:-60}"
RUN_TIME="${RUN_TIME:-8m}"

export CF_DOMAIN

locust -f testing/locust/locustfile_cf_bustpath.py \
  --headless -u "${USERS}" -r "${SPAWN_RATE}" \
  --run-time "${RUN_TIME}" --stop-timeout 30 --only-summary
