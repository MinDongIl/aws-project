#!/usr/bin/env bash
set -euo pipefail

STACK_ALB="traffic-alb-asg"
STACK_CDN="traffic-cdn"
REGION_ALB="${REGION_ALB:-ap-northeast-2}"
REGION_CLOUDFRONT="us-east-1"
TEMPLATE_FILE="${TEMPLATE_FILE:-cloudfront.yaml}"

ALT_DOMAIN="${ALT_DOMAIN:-}"
ACM_ARN="${ACM_ARN:-}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
PRICE_CLASS="${PRICE_CLASS:-PriceClass_All}"
ORIGIN_PROTO="${ORIGIN_PROTO:-http-only}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alt-domain) ALT_DOMAIN="$2"; shift 2;;
    --acm-arn) ACM_ARN="$2"; shift 2;;
    --hosted-zone-id) HOSTED_ZONE_ID="$2"; shift 2;;
    --price-class) PRICE_CLASS="$2"; shift 2;;
    --origin-proto) ORIGIN_PROTO="$2"; shift 2;;
    --alb-region) REGION_ALB="$2"; shift 2;;
    --cdn-stack) STACK_CDN="$2"; shift 2;;
    --alb-stack) STACK_ALB="$2"; shift 2;;
    --template) TEMPLATE_FILE="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

echo "[INFO] Discovering ALB DNS from stack: $STACK_ALB (region $REGION_ALB)"
ALB_DNS="$(aws cloudformation describe-stacks \
  --region "$REGION_ALB" \
  --stack-name "$STACK_ALB" \
  --query "Stacks[0].Outputs[?OutputKey=='ALBDNSName'].OutputValue" \
  --output text 2>/dev/null || true)"

if [[ -z "${ALB_DNS}" || "${ALB_DNS}" == "None" ]]; then
  echo "[ERROR] Could not find Output 'ALBDNSName' in stack $STACK_ALB."
  echo "[HINT] Export ALBDNSName in the ALB stack or pass ORIGIN_DNS manually:"
  echo "  ORIGIN_DNS=my-alb-xyz.ap-northeast-2.elb.amazonaws.com $0 [args]"
  exit 2
fi

ORIGIN_DNS="${ORIGIN_DNS:-$ALB_DNS}"
echo "[INFO] ORIGIN_DNS=${ORIGIN_DNS}"

# For 'aws cloudformation deploy', use Key=Value form (NOT ParameterKey/ParameterValue)
PARAM_ARGS=(
  OriginDomainName="${ORIGIN_DNS}"
  PriceClass="${PRICE_CLASS}"
  OriginProtocolPolicy="${ORIGIN_PROTO}"
)

if [[ -n "$ALT_DOMAIN" && -n "$ACM_ARN" ]]; then
  PARAM_ARGS+=(
    AlternateDomainName="${ALT_DOMAIN}"
    AcmCertificateArn="${ACM_ARN}"
  )
fi

if [[ -n "$HOSTED_ZONE_ID" && -n "$ALT_DOMAIN" && -n "$ACM_ARN" ]]; then
  PARAM_ARGS+=(
    HostedZoneId="${HOSTED_ZONE_ID}"
  )
fi

echo "[INFO] Deploying CloudFront stack '$STACK_CDN' in $REGION_CLOUDFRONT"
aws cloudformation deploy \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_CDN" \
  --template-file "$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides "${PARAM_ARGS[@]}"

echo "[INFO] Fetching outputs..."
aws cloudformation describe-stacks \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_CDN" \
  --query "Stacks[0].Outputs[].[OutputKey,OutputValue]" \
  --output table
