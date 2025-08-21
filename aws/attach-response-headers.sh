#!/usr/bin/env bash
set -euo pipefail

# CloudFront 분배 ID 고정
DISTRIBUTION_ID="E3AG25VNNZ6FHO"

# 정책 ID를 가져올 리전(us-east-1에 스택 배포했음)
STACK_EXPORT_REGION="${STACK_EXPORT_REGION:-us-east-1}"

# 경로 패턴(필요 시 환경변수로 덮어쓰기 가능)
IFS=' ' read -r -a STATIC_PATTERNS <<< "${STATIC_PATTERNS_OVERRIDE:-/static/* /assets/* /images/* /js/* /css/*}"
IFS=' ' read -r -a HTML_PATTERNS   <<< "${HTML_PATTERNS_OVERRIDE:-*.html}"

command -v jq >/dev/null 2>&1 || { echo "jq가 필요합니다."; exit 1; }

# Response Headers Policy ID 로드
RHP_STATIC_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" \
  --query "Exports[?Name=='rhp-static-immutable-id'].Value | [0]" --output text)
RHP_HTML_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" \
  --query "Exports[?Name=='rhp-html-short-id'].Value | [0]" --output text)

for v in RHP_STATIC_ID RHP_HTML_ID; do
  if [ -z "${!v}" ] || [ "${!v}" = "None" ]; then
    echo "필수 Export(${v})를 찾을 수 없습니다."; exit 1
  fi
done

# 현재 분배 설정 로드
TMP_JSON=$(mktemp)
aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" > "$TMP_JSON"
ETAG=$(jq -r '.ETag' "$TMP_JSON")
jq '.DistributionConfig' "$TMP_JSON" > dist.json

# 기본 동작: HTML 짧은 헤더 정책 연결
jq --arg rhp "$RHP_HTML_ID" '
  .DefaultCacheBehavior += {ResponseHeadersPolicyId:$rhp}
' dist.json > dist.json.tmp && mv dist.json.tmp dist.json

# 특정 PathPattern 교체 함수
apply_rhp() {
  local pattern="$1" rhp_id="$2"
  jq --arg p "$pattern" --arg rhp "$rhp_id" '
    if .CacheBehaviors? and .CacheBehaviors.Items?
    then (.CacheBehaviors.Items[] | select(.PathPattern==$p)) += {ResponseHeadersPolicyId:$rhp}
    else .
    end
  ' dist.json > dist.json.tmp && mv dist.json.tmp dist.json
}

# 정적 경로: Immutable 헤더 정책
for p in "${STATIC_PATTERNS[@]}"; do apply_rhp "$p" "$RHP_STATIC_ID"; done
# HTML 경로: 짧은 헤더 정책
for p in "${HTML_PATTERNS[@]}";   do apply_rhp "$p" "$RHP_HTML_ID";   done

# 분배 업데이트
aws cloudfront update-distribution \
  --id "$DISTRIBUTION_ID" \
  --if-match "$ETAG" \
  --distribution-config file://dist.json >/dev/null

echo "완료: Response Headers Policy 연결 완료"
echo "- STATIC: ${STATIC_PATTERNS[*]} -> rhp:${RHP_STATIC_ID}"
echo "- HTML  : ${HTML_PATTERNS[*]}   -> rhp:${RHP_HTML_ID}"
echo "- DefaultBehavior               -> rhp:${RHP_HTML_ID}"
