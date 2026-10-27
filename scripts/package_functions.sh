#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/task"
BUILD_DIR="$ROOT/build"
ZIP_PATH="$BUILD_DIR/refund_worker.zip"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

python3 - <<'PY'
import os
import zipfile

root = "/root/task/functions"
zip_path = "/root/task/build/refund_worker.zip"
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for current, _, files in os.walk(root):
        for name in files:
            if name.endswith(".py"):
                full = os.path.join(current, name)
                arc = os.path.relpath(full, root)
                zf.write(full, arc)
PY

echo "packaged $ZIP_PATH"
