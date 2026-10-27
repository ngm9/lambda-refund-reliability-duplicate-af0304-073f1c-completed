#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"

log() { echo "[teardown] $*"; }

log "destroying Terraform stack"
cd "$ROOT/infra"
terraform destroy -auto-approve -input=false || true

log "done"
