#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="refund-settlements-${ACCOUNT_ID}"

main_url=$(aws sqs get-queue-url --queue-name refund-settlement-requests --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')
dlq_url=$(aws sqs get-queue-url --queue-name refund-settlement-dlq --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["QueueUrl"])')

echo "--- queue attributes ---"
aws sqs get-queue-attributes --queue-url "$main_url" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible VisibilityTimeout --output json

echo "--- dead-letter queue attributes ---"
aws sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --output json

echo "--- ledger scan ---"
aws dynamodb scan --table-name refund-settlement-ledger --output json

echo "--- settlement objects ---"
aws s3api list-objects-v2 --bucket "$BUCKET" --output json
