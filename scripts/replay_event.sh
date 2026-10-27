#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"
FIXTURE="${1:-$ROOT/fixtures/valid_refund.json}"
COUNT="${2:-2}"

for i in $(seq 1 "$COUNT"); do
  bash "$ROOT/scripts/send_event.sh" "$FIXTURE"
done
