#!/usr/bin/env bash
set -euo pipefail

STACK_CDN="${STACK_CDN:-traffic-cdn}"
STACK_WAF="${STACK_WAF:-traffic-waf}"
REGION_CLOUDFRONT="us-east-1"
TEMPLATE_WAF="${TEMPLATE_WAF:-waf.yaml}"
TEMPLATE_CDN="${TEMPLATE_CDN:-cloudfront-v3.yaml}"

WEBACL_NAME="${WEBACL_NAME:-traffic-waf}"
RATE_LIMIT="${RATE_LIMIT:-2000}"

echo "[INFO] Fetching CloudFront DistributionId from stack: $STACK_CDN"
DIST_ID="$(aws cloudformation describe-stacks \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_CDN" \
  --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" \
  --output text)"
if [[ -z "$DIST_ID" || "$DIST_ID" == "None" ]]; then
  echo "[ERROR] Could not resolve DistributionId from stack '$STACK_CDN' in $REGION_CLOUDFRONT"
  exit 2
fi
echo "[INFO] DistributionId=$DIST_ID"

echo "[INFO] Deploying WAF stack '$STACK_WAF' in $REGION_CLOUDFRONT"
aws cloudformation deploy \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_WAF" \
  --template-file "$TEMPLATE_WAF" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
    WebAclName="$WEBACL_NAME" \
    RateLimit="$RATE_LIMIT"

WEBACL_ARN="$(aws cloudformation describe-stacks \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_WAF" \
  --query "Stacks[0].Outputs[?OutputKey=='WebACLArn'].OutputValue" \
  --output text)"
if [[ -z "$WEBACL_ARN" || "$WEBACL_ARN" == "None" ]]; then
  echo "[ERROR] Failed to resolve WebACLArn from stack '$STACK_WAF'"
  exit 3
fi
echo "[INFO] WebACLArn=$WEBACL_ARN"

echo "[INFO] Updating CloudFront stack '$STACK_CDN' with WebACL"
aws cloudformation deploy \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_CDN" \
  --template-file "$TEMPLATE_CDN" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
    WebACLArn="$WEBACL_ARN"

echo "[INFO] Done."
