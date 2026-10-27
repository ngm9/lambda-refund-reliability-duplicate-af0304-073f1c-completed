#!/usr/bin/env bash
set -euo pipefail

queue_url=$(aws sqs get-queue-url --queue-name refund-settlement-requests --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')
visibility=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names VisibilityTimeout --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Attributes"]["VisibilityTimeout"])')
timeout=$(aws lambda get-function-configuration --function-name refund-settlement-worker --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Timeout"])')

if (( visibility <= timeout )); then
  echo "expected queue delivery timing to exceed function timeout; visibility=$visibility timeout=$timeout" >&2
  exit 1
fi

echo "delivery timing check passed"
