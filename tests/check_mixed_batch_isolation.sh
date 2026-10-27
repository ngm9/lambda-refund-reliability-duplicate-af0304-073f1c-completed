#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"

ledger_count_for() {
  local refund_id="$1"
  aws dynamodb scan --table-name refund-settlement-ledger --output json | python3 - "$refund_id" <<'PY'
import json
import sys
refund_id = sys.argv[1]
data = json.load(sys.stdin)
print(sum(1 for item in data.get("Items", []) if item.get("refund_id", {}).get("S") == refund_id))
PY
}

dlq_visible() {
  local dlq_url
  dlq_url=$(aws sqs get-queue-url --queue-name refund-settlement-dlq --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')
  aws sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names ApproximateNumberOfMessages --output json | python3 <<'PY'
import json
import sys
data = json.load(sys.stdin)
print(int(data.get("Attributes", {}).get("ApproximateNumberOfMessages", "0")))
PY
}

bash "$ROOT/scripts/reset_state.sh" >/dev/null
bash "$ROOT/scripts/send_mixed_batch.sh" >/dev/null
sleep 20

first_count=$(ledger_count_for "rfd-2024-1001")
second_count=$(ledger_count_for "rfd-2024-1002")
dlq_count=$(dlq_visible)

if [[ "$first_count" != "1" ]]; then
  echo "expected healthy refund rfd-2024-1001 to settle once, found $first_count" >&2
  exit 1
fi

if [[ "$second_count" != "1" ]]; then
  echo "expected healthy refund rfd-2024-1002 to settle once, found $second_count" >&2
  exit 1
fi

if (( dlq_count < 1 )); then
  echo "expected malformed refund to be visible outside the main queue" >&2
  exit 1
fi

echo "mixed batch isolation check passed"
