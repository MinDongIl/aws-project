#!/usr/bin/env bash
set -euo pipefail

: "${ASG_NAME:?set ASG_NAME}"
: "${ALB_DNS:?set ALB_DNS}"
REGION="${REGION:-ap-northeast-2}"
TARGET_VALUE="${TARGET_VALUE:-80}"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancers[?DNSName=='${ALB_DNS}'].LoadBalancerArn" \
  --output text)
[ -n "$LB_ARN" ] && [ "$LB_ARN" != "None" ] || { echo "[FAIL] ALB not found for DNS=${ALB_DNS}"; exit 1; }

TG_ARN=$(aws elbv2 describe-target-groups \
  --region "$REGION" \
  --load-balancer-arn "$LB_ARN" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)
[ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ] || { echo "[FAIL] TargetGroup not found for LB"; exit 1; }

LB_LABEL="${LB_ARN#*loadbalancer/}"   # app/<lb-name>/<lb-hash>
TG_LABEL="${TG_ARN#*targetgroup/}"    # <tg-name>/<tg-hash>
RESOURCE_LABEL="${LB_LABEL}/targetgroup/${TG_LABEL}"

echo "[INFO] RESOURCE_LABEL=${RESOURCE_LABEL}"

# Find existing TargetTracking policy for ALBRequestCountPerTarget with same ResourceLabel
EXISTING_NAME=$(aws autoscaling describe-policies \
  --region "$REGION" \
  --auto-scaling-group-name "$ASG_NAME" \
  --query '
    ScalingPolicies[?
      PolicyType==`TargetTrackingScaling` &&
      TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType==`ALBRequestCountPerTarget` &&
      TargetTrackingConfiguration.PredefinedMetricSpecification.ResourceLabel==`'"${RESOURCE_LABEL}"'`
    ].PolicyName | [0]' \
  --output text)

if [ -n "$EXISTING_NAME" ] && [ "$EXISTING_NAME" != "None" ]; then
  POLICY_NAME="$EXISTING_NAME"
  echo "[INFO] Updating existing policy: ${POLICY_NAME}"
else
  POLICY_NAME="tt-req-per-target"
  echo "[INFO] Creating policy: ${POLICY_NAME}"
fi

POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --region "$REGION" \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-type "TargetTrackingScaling" \
  --target-tracking-configuration "{
    \"PredefinedMetricSpecification\": {
      \"PredefinedMetricType\": \"ALBRequestCountPerTarget\",
      \"ResourceLabel\": \"${RESOURCE_LABEL}\"
    },
    \"TargetValue\": ${TARGET_VALUE},
    \"DisableScaleIn\": false
  }" \
  --query "PolicyARN" --output text)

echo "[OK] Ensured TargetTracking(RequestCountPerTarget)"
echo "[INFO] PolicyName=${POLICY_NAME}"
echo "[INFO] PolicyARN=${POLICY_ARN}"
echo "[INFO] TargetValue=${TARGET_VALUE}"
