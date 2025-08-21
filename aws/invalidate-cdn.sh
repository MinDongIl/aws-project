#!/usr/bin/env bash
set -euo pipefail

STACK_CDN="${STACK_CDN:-traffic-cdn}"
REGION_CLOUDFRONT="us-east-1"
PATHS="${PATHS:-/*}"

DIST_ID="$(aws cloudformation describe-stacks \
  --region "$REGION_CLOUDFRONT" \
  --stack-name "$STACK_CDN" \
  --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" \
  --output text)"

aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "$PATHS"
