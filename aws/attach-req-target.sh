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

# extract labels (no ARN prefixes)
LB_LABEL="${LB_ARN#*loadbalancer/}"     # e.g. app/traffic-alb-asg-alb/06598219fcaf0e81
TG_LABEL="${TG_ARN#*targetgroup/}"      # e.g. traffi-Targe-HGHEJSQK0CG6/115715a4d3c410f2
RESOURCE_LABEL="${LB_LABEL}/targetgroup/${TG_LABEL}"

case "$LB_LABEL$TG_LABEL" in
  *arn:aws*) echo "[FAIL] label parse failed"; exit 1;;
esac

echo "[INFO] LB_LABEL=${LB_LABEL}"
echo "[INFO] TG_LABEL=${TG_LABEL}"
echo "[INFO] ResourceLabel=${RESOURCE_LABEL}"

POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --region "$REGION" \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name "tt-req-per-target" \
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

echo "[OK] Attached TargetTracking(RequestCountPerTarget)"
echo "[INFO] PolicyARN=${POLICY_ARN}"
