#!/usr/bin/env bash
set -euo pipefail

# CloudFront 배포 ID (수정 완료)
DISTRIBUTION_ID="E3AG25VNNZ6FHO"

REGION="${REGION:-us-east-1}"
STACK_EXPORT_REGION="${STACK_EXPORT_REGION:-$REGION}"

# 기본 패턴
STATIC_PATTERNS=("/static/*" "/assets/*" "/images/*" "/js/*" "/css/*")
HTML_PATTERNS=("*.html")
API_PATTERNS=("/api/*")

command -v jq >/dev/null 2>&1 || { echo "jq가 필요합니다. (sudo yum install jq 또는 apt install jq)"; exit 1; }

# 정책 ID 로드
CP_STATIC_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" --query "Exports[?Name=='cp-static-long-ttl-id'].Value | [0]" --output text)
CP_HTML_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" --query "Exports[?Name=='cp-html-short-ttl-id'].Value | [0]" --output text)
CP_API_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" --query "Exports[?Name=='cp-api-no-cache-id'].Value | [0]" --output text)
ORP_STATIC_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" --query "Exports[?Name=='orp-static-minimal-id'].Value | [0]" --output text)
ORP_API_ID=$(aws cloudformation list-exports --region "$STACK_EXPORT_REGION" --query "Exports[?Name=='orp-api-all-id'].Value | [0]" --output text)

for v in CP_STATIC_ID CP_HTML_ID CP_API_ID ORP_STATIC_ID ORP_API_ID; do
  if [ -z "${!v}" ] || [ "${!v}" = "None" ]; then
    echo "필수 Export(${v})를 찾을 수 없습니다."; exit 1
  fi
done

TMP_JSON=$(mktemp)
aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" > "$TMP_JSON"
ETAG=$(jq -r '.ETag' "$TMP_JSON")
jq '.DistributionConfig' "$TMP_JSON" > dist.json

# 기본 동작: HTML 짧은 캐시
jq --arg cp "$CP_HTML_ID" --arg orp "$ORP_STATIC_ID" '
  .DefaultCacheBehavior += {CachePolicyId:$cp, OriginRequestPolicyId:$orp, Compress:true}
' dist.json > dist.json.tmp && mv dist.json.tmp dist.json

apply_policy() {
  local pattern="$1" cp_id="$2" orp_id="$3"
  jq --arg p "$pattern" --arg cp "$cp_id" --arg orp "$orp_id" '
    if .CacheBehaviors? and .CacheBehaviors.Items?
    then (.CacheBehaviors.Items[] | select(.PathPattern==$p)) += {CachePolicyId:$cp, OriginRequestPolicyId:$orp, Compress:true}
    else .
    end
  ' dist.json > dist.json.tmp && mv dist.json.tmp dist.json
}

for p in "${STATIC_PATTERNS[@]}"; do apply_policy "$p" "$CP_STATIC_ID" "$ORP_STATIC_ID"; done
for p in "${HTML_PATTERNS[@]}";   do apply_policy "$p" "$CP_HTML_ID"   "$ORP_STATIC_ID"; done
for p in "${API_PATTERNS[@]}";    do apply_policy "$p" "$CP_API_ID"    "$ORP_API_ID";    done

aws cloudfront update-distribution \
  --id "$DISTRIBUTION_ID" \
  --if-match "$ETAG" \
  --distribution-config file://dist.json >/dev/null

echo "완료: CloudFront 캐시/오리진 요청 정책 적용 완료"
echo "- STATIC: ${STATIC_PATTERNS[*]} -> cp:${CP_STATIC_ID} / orp:${ORP_STATIC_ID}"
echo "- HTML  : ${HTML_PATTERNS[*]}   -> cp:${CP_HTML_ID}   / orp:${ORP_STATIC_ID}"
echo "- API   : ${API_PATTERNS[*]}    -> cp:${CP_API_ID}    / orp:${ORP_API_ID}"
