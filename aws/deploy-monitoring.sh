#!/usr/bin/env bash
set -euo pipefail

REGION="ap-northeast-2"
ALB_ASG_STACK="traffic-alb-asg"
MON_STACK="traffic-monitoring"

# Fetch ASG physical name
ASG_NAME=$(aws cloudformation describe-stack-resources \
  --region "${REGION}" \
  --stack-name "${ALB_ASG_STACK}" \
  --query "StackResources[?LogicalResourceId=='ASG'].PhysicalResourceId" \
  --output text)

# Fetch ALB ARN and derive CloudWatch dimension full name: app/<name>/<id>
ALB_ARN=$(aws cloudformation describe-stack-resources \
  --region "${REGION}" \
  --stack-name "${ALB_ASG_STACK}" \
  --query "StackResources[?LogicalResourceId=='ALB'].PhysicalResourceId" \
  --output text)

# Fetch Target Group ARN and derive dimension full name: targetgroup/<name>/<id>
TG_ARN=$(aws cloudformation describe-stack-resources \
  --region "${REGION}" \
  --stack-name "${ALB_ASG_STACK}" \
  --query "StackResources[?LogicalResourceId=='TargetGroup'].PhysicalResourceId" \
  --output text)

if [[ -z "${ASG_NAME}" || -z "${ALB_ARN}" || -z "${TG_ARN}" || "${ASG_NAME}" == "None" ]]; then
  echo "[ERROR] Failed to resolve required resources from stack: ${ALB_ASG_STACK}"
  exit 1
fi

# Convert ARNs to CloudWatch dimension names
# ALB ARN example: arn:aws:elasticloadbalancing:region:acct:loadbalancer/app/name/hash
# We need "app/name/hash"
ALB_FULL_NAME=$(echo "${ALB_ARN}" | awk -F'loadbalancer/' '{print $2}')
# TG ARN example: arn:aws:elasticloadbalancing:region:acct:targetgroup/name/hash
# We need "targetgroup/name/hash"
TG_FULL_NAME=$(echo "${TG_ARN}" | awk -F':' '{print $6}')

echo "[INFO] ASG_NAME=${ASG_NAME}"
echo "[INFO] LoadBalancerFullName=${ALB_FULL_NAME}"
echo "[INFO] TargetGroupFullName=${TG_FULL_NAME}"

aws cloudformation deploy \
  --region "${REGION}" \
  --template-file monitoring.yaml \
  --stack-name "${MON_STACK}" \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    AutoScalingGroupName="${ASG_NAME}" \
    LoadBalancerFullName="${ALB_FULL_NAME}" \
    TargetGroupFullName="${TG_FULL_NAME}" \
    DashboardName="traffic-dashboard"

echo "[DONE] Monitoring stack deployed. Open CloudWatch dashboard: traffic-dashboard"
