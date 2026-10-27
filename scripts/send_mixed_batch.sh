#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"

bash "$ROOT/scripts/send_event.sh" "$ROOT/fixtures/valid_refund.json"
bash "$ROOT/scripts/send_event.sh" "$ROOT/fixtures/malformed_refund.json"
bash "$ROOT/scripts/send_event.sh" "$ROOT/fixtures/valid_refund_second.json"

echo "sent mixed refund group"
