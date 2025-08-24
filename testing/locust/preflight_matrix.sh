#!/usr/bin/env bash
set -euo pipefail

: "${CF_DOMAIN:?Set CF_DOMAIN like traffic.nextcloudlab.com}"
: "${ALB_DNS:?Set ALB_DNS like traffic-alb-asg-alb-xxxx.ap-northeast-2.elb.amazonaws.com}"

CANDIDATES=(
  "/api/health" "/api/ping" "/api/status"
  "/health" "/ping" "/status"
  "/" "/version"
)

echo "[INFO] Checking candidates on CF and ALB"
printf "%-22s %-8s %-8s\n" "PATH" "CF" "ALB"
for p in "${CANDIDATES[@]}"; do
  cf_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Cache-Control: no-cache" "https://${CF_DOMAIN}${p}")
  alb_code_http=$(curl -s -o /dev/null -w "%{http_code}" -H "Cache-Control: no-cache" "http://${ALB_DNS}${p}" || true)
  alb_code_https=$(curl -s -o /dev/null -w "%{http_code}" -H "Cache-Control: no-cache" "https://${ALB_DNS}${p}" || true)
  alb_code="${alb_code_http}"
  [[ "${alb_code_https}" =~ ^2|3$ ]] && alb_code="${alb_code_https}"
  printf "%-22s %-8s %-8s\n" "${p}" "${cf_code}" "${alb_code}"
done
