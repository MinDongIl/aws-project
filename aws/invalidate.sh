#!/usr/bin/env bash
set -euo pipefail

# CloudFront 분배 ID (고정)
DISTRIBUTION_ID="E3AG25VNNZ6FHO"

# 기본 무효화 대상 (필요 시 인자나 환경변수로 덮어쓰기)
# - HTML만 부분 무효화: 인덱스/문서 경로 위주
DEFAULT_PATHS=( "/" "/index.html" "/*.html" )

# 인자로 경로를 넘기면 그것만 무효화한다. (예: ./invalidate.sh / /index.html /docs/*.html)
if [ "$#" -gt 0 ]; then
  PATHS=( "$@" )
elif [ -n "${INVALIDATE_PATHS:-}" ]; then
  # 환경변수로 공백 구분 목록을 받을 수 있음
  read -r -a PATHS <<< "${INVALIDATE_PATHS}"
else
  PATHS=( "${DEFAULT_PATHS[@]}" )
fi

# 전체 무효화는 비용/시간 ↑ 이므로 정말 필요한 경우에만 사용해라.
if [ "${INVALIDATE_ALL:-false}" = "true" ]; then
  PATHS=( "/*" )
fi

# 경로를 JSON 배열로 가공
ITEMS_JSON=$(printf '"%s",' "${PATHS[@]}")
ITEMS_JSON="[${ITEMS_JSON%,}]"

# 무효화 생성
CALLER_REF="inv-$(date +%Y%m%d-%H%M%S)-$RANDOM"

aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --invalidation-batch "{
    \"Paths\": { \"Quantity\": ${#PATHS[@]}, \"Items\": ${ITEMS_JSON} },
    \"CallerReference\": \"${CALLER_REF}\"
  }" \
  --output table
