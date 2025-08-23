#!/usr/bin/env bash
REGION="ap-northeast-2"
ASG_NAME="traffic-alb-asg-ASG-W9KjceZQEG9R"

while true; do
  NOW=$(date '+%Y-%m-%d %H:%M:%S')
  DESIRED=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --auto-scaling-group-names "$ASG_NAME" --query "AutoScalingGroups[0].DesiredCapacity" --output text)
  IN_SERVICE=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --auto-scaling-group-names "$ASG_NAME" --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'] | length(@)" --output text)

  CPU=$(aws cloudwatch get-metric-statistics \
    --region "$REGION" \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --statistics Average \
    --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
    --start-time $(date -u -d '3 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 60 \
    --query "Datapoints[-1].Average" --output text)

  echo "[$NOW] Desired=$DESIRED InService=$IN_SERVICE AvgCPU(1m)=${CPU}%"
  sleep 15
done
