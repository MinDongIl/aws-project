#!/usr/bin/env bash
set -euo pipefail

: "${CF_DOMAIN:?Set CF_DOMAIN, e.g., traffic.nextcloudlab.com}"
PATH_DEFAULT="${PATH_DEFAULT:-/api/health}"
URL="https://${CF_DOMAIN}${PATH_DEFAULT}"

echo "[INFO] GET ${URL}"
code=$(curl -s -o /dev/null -w "%{http_code}" -H "Cache-Control: no-cache" "${URL}")
if [[ "$code" =~ ^2|3 ]]; then
  echo "[OK] ${code} from CloudFront → ALB"
else
  echo "[FAIL] HTTP ${code} from CloudFront → ALB"
  exit 1
fi
