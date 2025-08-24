#!/usr/bin/env bash
set -euo pipefail

TABLE="${TABLE:-traffic-session}"
PRIMARY_REGION="${PRIMARY_REGION:-ap-northeast-2}"
SECONDARY_REGION="${SECONDARY_REGION:-ap-northeast-1}"
USER_ID="${USER_ID:-u-$(date +%s)}"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TTL_EPOCH="$(($(date +%s)+3600))"
PK="USER#${USER_ID}"
SK="TS#${NOW_ISO}"

echo "[PUT] $TABLE $PRIMARY_REGION $PK $SK"
aws dynamodb put-item \
  --region "$PRIMARY_REGION" \
  --table-name "$TABLE" \
  --item "{
    \"pk\": {\"S\": \"$PK\"},
    \"sk\": {\"S\": \"$SK\"},
    \"userId\": {\"S\": \"$USER_ID\"},
    \"createdAt\": {\"S\": \"$NOW_ISO\"},
    \"ttl\": {\"N\": \"$TTL_EPOCH\"}
  }"

echo "[GET primary]"
aws dynamodb get-item \
  --region "$PRIMARY_REGION" \
  --table-name "$TABLE" \
  --key "{\"pk\":{\"S\":\"$PK\"},\"sk\":{\"S\":\"$SK\"}}" \
  --consistent-read

echo "[WAIT replication -> $SECONDARY_REGION]"
for i in {1..30}; do
  if aws dynamodb get-item \
      --region "$SECONDARY_REGION" \
      --table-name "$TABLE" \
      --key "{\"pk\":{\"S\":\"$PK\"},\"sk\":{\"S\":\"$SK\"}}" \
      --query "Item.pk.S" --output text | grep -q "$PK"; then
    echo "[OK] replicated (try=$i)"
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "[WARN] not visible in $SECONDARY_REGION within timeout"; exit 2
  fi
done

echo "[DONE] pk=$PK sk=$SK userId=$USER_ID createdAt=$NOW_ISO"
