#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="refund-settlements-${ACCOUNT_ID}"

queue_url=$(aws sqs get-queue-url --queue-name refund-settlement-requests --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')
dlq_url=$(aws sqs get-queue-url --queue-name refund-settlement-dlq --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')
aws sqs purge-queue --queue-url "$queue_url" >/dev/null 2>&1 || true
aws sqs purge-queue --queue-url "$dlq_url" >/dev/null 2>&1 || true

scan_file=$(mktemp)
aws dynamodb scan --table-name refund-settlement-ledger --projection-expression settlement_id --output json > "$scan_file"
python3 - "$scan_file" <<'PY' | while read -r settlement_id; do
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
for item in data.get("Items", []):
    value = item.get("settlement_id", {}).get("S")
    if value:
        print(value)
PY
  aws dynamodb delete-item --table-name refund-settlement-ledger --key "{\"settlement_id\":{\"S\":\"$settlement_id\"}}" >/dev/null || true
done
rm -f "$scan_file"

objects_file=$(mktemp)
aws s3api list-objects-v2 --bucket "$BUCKET" --output json > "$objects_file" || true
python3 - "$objects_file" <<'PY' | while read -r key; do
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
for item in data.get("Contents", []) or []:
    key = item.get("Key")
    if key:
        print(key)
PY
  aws s3api delete-object --bucket "$BUCKET" --key "$key" >/dev/null || true
done
rm -f "$objects_file"

sleep 2
echo "state reset"
