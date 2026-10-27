#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"
FIXTURE="${1:-$ROOT/fixtures/valid_refund.json}"

if [[ ! -f "$FIXTURE" ]]; then
  echo "fixture not found: $FIXTURE" >&2
  exit 1
fi

QUEUE_URL=$(aws sqs get-queue-url --queue-name refund-settlement-requests --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')
BODY=$(python3 - "$FIXTURE" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    print(json.dumps(json.load(fh), separators=(",", ":")))
PY
)

aws sqs send-message --queue-url "$QUEUE_URL" --message-body "$BODY" >/dev/null
echo "sent $(basename "$FIXTURE")"
