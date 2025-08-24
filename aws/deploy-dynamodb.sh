#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-ap-northeast-2}"
STACK="${STACK:-traffic-dynamodb}"
TABLE_NAME="${TABLE_NAME:-traffic-session}"
PRIMARY_REGION="${PRIMARY_REGION:-ap-northeast-2}"
SECONDARY_REGION="${SECONDARY_REGION:-ap-northeast-1}"
TTL_ATTR="${TTL_ATTR:-ttl}"

echo "[INFO] Deploying DynamoDB Global Table stack: $STACK in $REGION"
aws cloudformation deploy \
  --region "$REGION" \
  --stack-name "$STACK" \
  --template-file "dynamodb-global-table.yaml" \
  --parameter-overrides \
      TableName="$TABLE_NAME" \
      PrimaryRegion="$PRIMARY_REGION" \
      SecondaryRegion="$SECONDARY_REGION" \
      TTLAttributeName="$TTL_ATTR" \
  --capabilities CAPABILITY_NAMED_IAM

echo "[INFO] Deployed. Stack outputs:"
aws cloudformation describe-stacks \
  --region "$REGION" \
  --stack-name "$STACK" \
  --query "Stacks[0].Outputs"
