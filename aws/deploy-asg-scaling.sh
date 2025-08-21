#!/usr/bin/env bash
set -euo pipefail

REGION="ap-northeast-2"
ALB_ASG_STACK="traffic-alb-asg"
SCALING_STACK="traffic-asg-scaling"

# 1) Get ASG PhysicalResourceId from the previous stack
ASG_NAME=$(aws cloudformation describe-stack-resources \
  --region "${REGION}" \
  --stack-name "${ALB_ASG_STACK}" \
  --query "StackResources[?LogicalResourceId=='ASG'].PhysicalResourceId" \
  --output text)

echo "[INFO] Using ASG_NAME=${ASG_NAME}"

# 2) Deploy scaling policy + CPU alarm
aws cloudformation deploy \
  --region "${REGION}" \
  --template-file asg-scaling.yaml \
  --stack-name "${SCALING_STACK}" \
  --parameter-overrides \
    AutoScalingGroupName="${ASG_NAME}" \
    CpuTargetPercent=60 \
    CpuAlarmThreshold=80

echo "[DONE] Deployed scaling policy and CPU alarm to ASG: ${ASG_NAME}"
