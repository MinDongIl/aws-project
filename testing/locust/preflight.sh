#!/usr/bin/env bash
set -euo pipefail

DEFAULT_HOST="http://traffic-alb-asg-alb-934945083.ap-northeast-2.elb.amazonaws.com"
TARGET_BASE_URL="${TARGET_BASE_URL:-$DEFAULT_HOST}"

STATUS_CANDIDATES="${STATUS_CANDIDATES:-/api/v1/status,/status,/healthz,/health,/}"
STATIC_CANDIDATES="${STATIC_CANDIDATES:-/static/app.js,/index.html,/}"

host_only() {
  echo "$TARGET_BASE_URL" | sed -E 's#https?://([^/]+)/?.*#\1#'
}

http_ok() {
  local url="$1"
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo 000)"
  case "$code" in
    200|201|202|204|301|302|304) return 0 ;;
    *) return 1 ;;
  esac
}

pick_first_ok() {
  local base="$1" ; local csv="$2"
  IFS=',' read -r -a arr <<< "$csv"
  for p in "${arr[@]}"; do
    if http_ok "$base$p"; then echo "$p"; return 0; fi
  done
  return 1
}

echo "[CHECK] target=$TARGET_BASE_URL"
nslookup "$(host_only)" >/dev/null || { echo "[FAIL] DNS lookup failed"; exit 1; }

sp="$(pick_first_ok "$TARGET_BASE_URL" "$STATUS_CANDIDATES")" || { echo "[FAIL] no 2xx/3xx among STATUS_CANDIDATES"; exit 1; }
echo "[OK] status path=$sp"

stp="$(pick_first_ok "$TARGET_BASE_URL" "$STATIC_CANDIDATES")" || { echo "[FAIL] no 2xx/3xx among STATIC_CANDIDATES"; exit 1; }
echo "[OK] static path=$stp"

echo "STATUS_PATH=$sp"
echo "STATIC_PATH=$stp"
