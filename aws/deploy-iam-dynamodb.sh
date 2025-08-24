#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-ap-northeast-2}"
STACK="${STACK:-traffic-iam-dynamodb}"
ROLE_NAME="${ROLE_NAME:?Set ROLE_NAME to your EC2 instance role name (e.g., traffic-ec2-role)}"
DDB_STACK="${DDB_STACK:-traffic-dynamodb}"

echo "[INFO] Resolving DynamoDB TableArn from stack: $DDB_STACK (region: $REGION)"
TABLE_ARN=$(aws cloudformation describe-stacks \
  --region "$REGION" \
  --stack-name "$DDB_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='TableArn'].OutputValue" \
  --output text)

if [[ -z "${TABLE_ARN:-}" || "${TABLE_ARN}" == "None" ]]; then
  echo "[ERROR] Failed to resolve TableArn from stack '$DDB_STACK'. Ensure 1) stack exists, 2) Outputs include TableArn."
  exit 1
fi

echo "[INFO] Attaching inline policy to role: $ROLE_NAME (TableArn: $TABLE_ARN)"
aws cloudformation deploy \
  --region "$REGION" \
  --stack-name "$STACK" \
  --template-file "iam-dynamodb-access.yaml" \
  --parameter-overrides RoleName="$ROLE_NAME" TableArn="$TABLE_ARN" \
  --capabilities CAPABILITY_NAMED_IAM

echo "[INFO] Verifying inline policies on role: $ROLE_NAME"
aws iam list-role-policies --role-name "$ROLE_NAME"

echo "[INFO] Done."
