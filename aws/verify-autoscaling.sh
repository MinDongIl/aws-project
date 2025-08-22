#!/usr/bin/env bash
set -euo pipefail

# === 필수 환경 ===
REGION="${REGION:-ap-northeast-2}"
ASG_NAME="${ASG_NAME:-traffic-alb-asg-ASG-W9KjceZQEG9R}"

# ALB / TG 리소스 라벨 (네 값 고정)
LB_LABEL="app/traffic-alb-asg-alb/06598219fcaf0e81"
TG_LABEL="targetgroup/traffi-Targe-HGHEJSQK0CG6/115715a4d3c410f2"

# 조회 기간 (최근 60분)
END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START=$(date -u -d "-60 minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc)-timedelta(minutes=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)

echo "==[1] 붙은 정책 확인 =="
aws autoscaling describe-policies \
  --region "$REGION" \
  --auto-scaling-group-name "$ASG_NAME" \
  --query "ScalingPolicies[].{Name:PolicyName,Type:PolicyType,Metric:TargetTrackingConfiguration.PredefinedMetricSpecification.PredefinedMetricType,Target:TargetTrackingConfiguration.TargetValue}" \
  --output table

echo
echo "==[2] 스케줄 확인 (야간 축소/주간 복구) =="
aws autoscaling describe-scheduled-actions \
  --region "$REGION" \
  --auto-scaling-group-name "$ASG_NAME" \
  --query "ScheduledUpdateGroupActions[].{Name:ScheduledActionName,Recurrence:Recurrence,Min:MinSize,Desired:DesiredCapacity}" \
  --output table

echo
echo "==[3] 최근 스케일 이벤트 (지난 24h) =="
aws autoscaling describe-scaling-activities \
  --region "$REGION" \
  --auto-scaling-group-name "$ASG_NAME" \
  --max-items 20 \
  --query "Activities[?StartTime>=\`$(date -u -d '-24 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || python - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc)-timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)\`].[StartTime,Description,StatusCode]" \
  --output table

echo
echo "==[4] CloudWatch 메트릭(최근 60m 스냅샷) =="

# (A) ALB: RequestCountPerTarget (평균 TPS 추정용)
aws cloudwatch get-metric-statistics \
  --region "$REGION" \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCountPerTarget \
  --dimensions Name=LoadBalancer,Value="$LB_LABEL" Name=TargetGroup,Value="$TG_LABEL" \
  --start-time "$START" --end-time "$END" --period 60 \
  --statistics Sum \
  --query "Datapoints[-1]" --output json | jq '. | {Metric:"ALB RequestCountPerTarget (per 60s)",Sample:.Timestamp,RequestsPerTarget:.Sum}'

# (B) ALB: TargetResponseTime (평균 지연)
aws cloudwatch get-metric-statistics \
  --region "$REGION" \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value="$LB_LABEL" Name=TargetGroup,Value="$TG_LABEL" \
  --start-time "$START" --end-time "$END" --period 60 \
  --statistics Average \
  --query "Datapoints[-1]" --output json | jq '. | {Metric:"ALB TargetResponseTime (s)",Sample:.Timestamp,AvgLatencySec:.Average}'

# (C) ASG: 현재 용량/서비스중 인스턴스
aws cloudwatch get-metric-statistics \
  --region "$REGION" \
  --namespace AWS/AutoScaling \
  --metric-name GroupDesiredCapacity \
  --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
  --start-time "$START" --end-time "$END" --period 60 \
  --statistics Average \
  --query "Datapoints[-1]" --output json | jq '. | {Metric:"ASG DesiredCapacity",Sample:.Timestamp,Desired: .Average}'

aws cloudwatch get-metric-statistics \
  --region "$REGION" \
  --namespace AWS/AutoScaling \
  --metric-name GroupInServiceInstances \
  --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
  --start-time "$START" --end-time "$END" --period 60 \
  --statistics Average \
  --query "Datapoints[-1]" --output json | jq '. | {Metric:"ASG InService",Sample:.Timestamp,InService: .Average}'

echo
echo "==[완료] 메트릭 요약 출력됨. 트래픽 넣고 다시 실행하면 변화를 볼 수 있음. =="
