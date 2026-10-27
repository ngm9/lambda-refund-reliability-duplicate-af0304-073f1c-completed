#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"
REFUND_ID="rfd-2024-1001"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="refund-settlements-${ACCOUNT_ID}"

count_ledger() {
  aws dynamodb scan --table-name refund-settlement-ledger --output json | python3 - "$REFUND_ID" <<'PY'
import json
import sys
refund_id = sys.argv[1]
data = json.load(sys.stdin)
print(sum(1 for item in data.get("Items", []) if item.get("refund_id", {}).get("S") == refund_id))
PY
}

count_objects() {
  aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "settlements/$REFUND_ID/" --output json | python3 <<'PY'
import json
import sys
data = json.load(sys.stdin)
print(len(data.get("Contents", []) or []))
PY
}

bash "$ROOT/scripts/reset_state.sh" >/dev/null
bash "$ROOT/scripts/replay_event.sh" "$ROOT/fixtures/valid_refund.json" 2 >/dev/null
sleep 8

ledger_count=$(count_ledger)
object_count=$(count_objects)

if [[ "$ledger_count" != "1" ]]; then
  echo "expected one ledger settlement for $REFUND_ID, found $ledger_count" >&2
  exit 1
fi

if [[ "$object_count" != "1" ]]; then
  echo "expected one settlement object for $REFUND_ID, found $object_count" >&2
  exit 1
fi

echo "idempotent replay check passed"
