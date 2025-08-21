
set -euo pipefail

REGION="ap-northeast-2"
VPC_STACK="traffic-vpc"
ALB_ASG_STACK="traffic-alb-asg"
REDIS_STACK="traffic-redis"

VPC_ID=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${VPC_STACK}" \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
  --output text)

PRIVATE_SUBNETS=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${VPC_STACK}" \
  --query "Stacks[0].Outputs[?OutputKey=='PrivateSubnetIds'].OutputValue" \
  --output text)

APP_SG_ID=$(aws cloudformation describe-stack-resources \
  --region "${REGION}" \
  --stack-name "${ALB_ASG_STACK}" \
  --query "StackResources[?LogicalResourceId=='InstanceSG'].PhysicalResourceId" \
  --output text)

echo "[INFO] VPC_ID=${VPC_ID}"
echo "[INFO] PRIVATE_SUBNETS=${PRIVATE_SUBNETS}"
echo "[INFO] APP_SG_ID=${APP_SG_ID}"

if [[ -z "${VPC_ID}" || -z "${PRIVATE_SUBNETS}" || -z "${APP_SG_ID}" || "${APP_SG_ID}" == "None" ]]; then
  echo "[ERROR] Required IDs missing. Check previous stacks."
  exit 1
fi

aws cloudformation deploy \
  --region "${REGION}" \
  --template-file cache-redis.yaml \
  --stack-name "${REDIS_STACK}" \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    VpcId="${VPC_ID}" \
    PrivateSubnets="${PRIVATE_SUBNETS}" \
    AppSecurityGroupId="${APP_SG_ID}" \
    NodeType="cache.t4g.micro" \
    EngineVersion="7.1" \
    EnableHA="false"


aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${REDIS_STACK}" \
  --query "Stacks[0].Outputs" \
  --output table
