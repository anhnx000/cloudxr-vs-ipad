#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v lua >/dev/null 2>&1; then
  echo "lua is not installed. Install Lua 5.1+ to run these tests."
  exit 1
fi

echo "Running recorder GPU capture simulation test..."
lua "$SCRIPT_DIR/recorder_gpu_capture_test.lua"

echo "Running cloudxr manager record feedback test..."
lua "$SCRIPT_DIR/cloudxr_manager_record_feedback_test.lua"

echo "All Lua tests passed."
