#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"

log() { echo "[build] $*"; }

log "packaging Lambda function"
bash "$ROOT/scripts/package_functions.sh"

log "applying Terraform against AWS"
cd "$ROOT/infra"
terraform init -input=false
terraform apply -auto-approve -input=false

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="refund-settlements-${ACCOUNT_ID}"

log "running smoke checks"
aws sqs get-queue-url --queue-name refund-settlement-requests >/dev/null
aws sqs get-queue-url --queue-name refund-settlement-dlq >/dev/null
aws lambda get-function --function-name refund-settlement-worker >/dev/null
aws s3api head-bucket --bucket "$BUCKET" >/dev/null
aws dynamodb describe-table --table-name refund-settlement-ledger >/dev/null

log "ready"
