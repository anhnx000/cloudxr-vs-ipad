#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_ROOT="${CXR_LOG_DIR:-$ROOT_DIR/logs/server}"
LATEST_DIR="$LOG_ROOT/latest"

if [ ! -d "$LATEST_DIR" ]; then
  echo "No log session found at: $LATEST_DIR"
  echo "Run ./run.sh first."
  exit 1
fi

echo "Log session: $LATEST_DIR"
echo "----------------------------------------"
echo "Recent LOVR logs:"
if [ -f "$LATEST_DIR/lovr.log" ]; then
  tail -n 120 "$LATEST_DIR/lovr.log"
else
  echo "lovr.log not found"
fi

echo ""
echo "----------------------------------------"
echo "Recent Record API logs:"
if [ -f "$LATEST_DIR/record_api.log" ]; then
  tail -n 120 "$LATEST_DIR/record_api.log"
else
  echo "record_api.log not found"
fi

echo ""
echo "----------------------------------------"
echo "Recorder status file:"
if [ -f /tmp/cloudxr_lovr_record_status.txt ]; then
  awk '1' /tmp/cloudxr_lovr_record_status.txt
else
  echo "/tmp/cloudxr_lovr_record_status.txt not found"
fi
