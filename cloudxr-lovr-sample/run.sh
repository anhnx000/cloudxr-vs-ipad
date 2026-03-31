#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: MIT
#
# =============================================================================
# CloudXR LOVR Run Script for Linux
# =============================================================================
# Convenience script to run the CloudXR example
# =============================================================================

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
DEVICE_PROFILE=""
for arg in "$@"; do
    case $arg in
        --webrtc)
            DEVICE_PROFILE="--webrtc"
            shift
            ;;
        --help|-h)
            echo "Usage: ./run.sh [options]"
            echo ""
            echo "Options:"
            echo "  --webrtc    Use Quest 3 device profile (Early Access)"
            echo "  --help      Show this help message"
            echo ""
            exit 0
            ;;
    esac
done

SESSION_TS="$(date +%Y%m%d_%H%M%S)"
LOG_ROOT="${CXR_LOG_DIR:-$(pwd)/logs/server}"
mkdir -p "$LOG_ROOT"
SESSION_LOG_DIR="$LOG_ROOT/$SESSION_TS"
mkdir -p "$SESSION_LOG_DIR"
LATEST_LOG_DIR="$LOG_ROOT/latest"
rm -rf "$LATEST_LOG_DIR"
ln -s "$SESSION_LOG_DIR" "$LATEST_LOG_DIR"

RUN_LOG_FILE="$SESSION_LOG_DIR/run.log"
LOVR_LOG_FILE="$SESSION_LOG_DIR/lovr.log"
exec > >(tee -a "$RUN_LOG_FILE") 2>&1

# Check if build/src exists
if [ ! -d "build/src" ]; then
    echo -e "${RED}❌ build/src/ directory not found!${NC}"
    echo -e "${YELLOW}Run ./build.sh first to build the project${NC}"
    exit 1
fi

# Detect build configuration
if [ -d "build/bin" ]; then
    LOVR_BIN="build/bin/lovr"
elif [ -d "build/Debug" ]; then
    LOVR_BIN="build/Debug/lovr"
elif [ -d "build/Release" ]; then
    LOVR_BIN="build/Release/lovr"
else
    echo -e "${RED}❌ Build output not found!${NC}"
    echo -e "${YELLOW}Run ./build.sh first to build the project${NC}"
    exit 1
fi

# Check if LOVR executable exists
if [ ! -f "$LOVR_BIN" ]; then
    echo -e "${RED}❌ LOVR executable not found at: $LOVR_BIN${NC}"
    echo -e "${YELLOW}Run ./build.sh first to build the project${NC}"
    exit 1
fi

# Check if example exists
EXAMPLE_PATH="build/src/plugins/nvidia/examples/cloudxr"
if [ ! -d "$EXAMPLE_PATH" ]; then
    echo -e "${RED}❌ CloudXR example not found at: $EXAMPLE_PATH${NC}"
    exit 1
fi

# Convert example path to absolute path before changing directories
EXAMPLE_ABS_PATH="$(realpath "$EXAMPLE_PATH")"

# Check for existing runtime_started file
# Mirror the runtime's logic for determining runtime directory
if [ -n "$XDG_RUNTIME_DIR" ]; then
    RUNTIME_DIR="$XDG_RUNTIME_DIR"
elif [ -n "$XDG_CACHE_HOME" ]; then
    RUNTIME_DIR="$XDG_CACHE_HOME"
else
    RUNTIME_DIR="$HOME/.cache"
fi

RUNTIME_STARTED_FILE="$RUNTIME_DIR/runtime_started"
if [ -f "$RUNTIME_STARTED_FILE" ]; then
    # Check if a lovr process is actually running; if not, the file is stale.
    if pgrep -x lovr > /dev/null 2>&1; then
        echo -e "${RED}❌ Another LOVR/CloudXR server appears to be running.${NC}"
        echo -e "${YELLOW}Kill it first, then remove: $RUNTIME_STARTED_FILE${NC}"
        exit 1
    else
        echo -e "${YELLOW}⚠️  Stale runtime lock found — removing: $RUNTIME_STARTED_FILE${NC}"
        rm -f "$RUNTIME_STARTED_FILE"
    fi
fi

# Set up CloudXR runtime environment
RUNTIME_JSON="$(pwd)/$(dirname "$LOVR_BIN")/openxr_cloudxr.json"
if [ ! -f "$RUNTIME_JSON" ]; then
    # Try to find it in the source lib directory
    SOURCE_RUNTIME_JSON="$(pwd)/plugins/nvidia/lib/linux-x86_64/openxr_cloudxr.json"
    if [ -f "$SOURCE_RUNTIME_JSON" ]; then
        echo -e "${YELLOW}Copying openxr_cloudxr.json to build directory...${NC}"
        cp "$SOURCE_RUNTIME_JSON" "$(dirname "$LOVR_BIN")/openxr_cloudxr.json"
        RUNTIME_JSON="$(pwd)/$(dirname "$LOVR_BIN")/openxr_cloudxr.json"
    else
        echo -e "${RED}❌ openxr_cloudxr.json not found!${NC}"
        echo -e "${YELLOW}Please ensure the CloudXR SDK files are properly installed.${NC}"
        echo -e "${YELLOW}The openxr_cloudxr.json file should be in:${NC}"
        echo -e "  plugins/nvidia/lib/linux-x86_64/openxr_cloudxr.json${NC}"
        exit 1
    fi
fi

# Convert to absolute path
RUNTIME_JSON="$(realpath "$RUNTIME_JSON")"

# Set OpenXR runtime to CloudXR
export XR_RUNTIME_JSON="$RUNTIME_JSON"

# Optional fallback record API for iPad flow (independent from OpenXR/headset).
RECORD_API_PID_FILE="/tmp/cloudxr_record_api.pid"
RECORD_API_LOG_FILE="$SESSION_LOG_DIR/record_api.log"
RECORD_API_SCRIPT="$(pwd)/tools/record_control_api.py"

if command -v python3 >/dev/null 2>&1 && [ -f "$RECORD_API_SCRIPT" ]; then
    if [ -f "$RECORD_API_PID_FILE" ] && kill -0 "$(cat "$RECORD_API_PID_FILE")" 2>/dev/null; then
        echo -e "${YELLOW}Record control API already running (PID: $(cat "$RECORD_API_PID_FILE")).${NC}"
    else
        DISPLAY="$DISPLAY" nohup python3 "$RECORD_API_SCRIPT" --host 0.0.0.0 --port 49080 --log-file "$RECORD_API_LOG_FILE" >> "$RUN_LOG_FILE" 2>&1 &
        echo "$!" > "$RECORD_API_PID_FILE"
        echo -e "${GREEN}Record control API started on :49080 (PID: $!).${NC}"
    fi
else
    echo -e "${YELLOW}Record control API not started (python3 or script missing).${NC}"
fi

# Run
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Running CloudXR LOVR Example${NC}"
echo -e "${BLUE}========================================${NC}"
if [ -n "$DEVICE_PROFILE" ]; then
    echo -e "${YELLOW}Device Profile: Quest 3 (Early Access)${NC}"
fi
echo -e "${YELLOW}XR Runtime JSON: $XR_RUNTIME_JSON${NC}"
echo -e "${GREEN}Starting LOVR...${NC}"
echo -e "${YELLOW}Log session dir: $SESSION_LOG_DIR${NC}"
echo -e "${YELLOW}LOVR log: $LOVR_LOG_FILE${NC}"
echo -e "${YELLOW}Record API log: $RECORD_API_LOG_FILE${NC}"
echo ""

cd "$(dirname "$LOVR_BIN")"
EXAMPLE_REL_PATH="$(realpath --relative-to="$(pwd)" "$EXAMPLE_ABS_PATH")"

# ── Stable virtual X display ──────────────────────────────────────────────
# LÖVR uses GLFW which needs an X11 display to drive its event loop.
# Using the real user Xorg (:1) is fragile — if the screen locks or the
# GNOME session restarts, the X connection breaks and LÖVR crashes.
# Instead we run a Xvfb (virtual framebuffer) on display :99.
# Vulkan/CloudXR rendering still goes through the NVIDIA GPU directly
# (via the Vulkan ICD), so off-screen rendering is hardware-accelerated.
XVFB_DISP=":99"
XVFB_PID_FILE="/tmp/cloudxr_xvfb.pid"
XVFB_STARTED=0

if command -v Xvfb >/dev/null 2>&1; then
    if [ -f "$XVFB_PID_FILE" ] && kill -0 "$(cat "$XVFB_PID_FILE")" 2>/dev/null; then
        echo -e "${YELLOW}Xvfb already running on $XVFB_DISP (PID: $(cat "$XVFB_PID_FILE")).${NC}"
    else
        Xvfb "$XVFB_DISP" -screen 0 1280x720x24 -ac -nolisten tcp +extension GLX >/dev/null 2>&1 &
        echo "$!" > "$XVFB_PID_FILE"
        XVFB_STARTED=1
        echo -e "${GREEN}Xvfb started on display $XVFB_DISP (PID: $!).${NC}"
        sleep 1
    fi
    export DISPLAY="$XVFB_DISP"
    echo -e "${YELLOW}Using virtual display: DISPLAY=$DISPLAY${NC}"
else
    echo -e "${YELLOW}Xvfb not found — using existing DISPLAY=$DISPLAY (may be unstable).${NC}"
    echo -e "${YELLOW}Install Xvfb: sudo apt install xvfb${NC}"
fi

# ── Watchdog: CloudXR runtime has an ~40s idle timeout on the OpenXR XR
# session when no client connects.  When LÖVR exits, port 48010 closes and
# the iPad gets 0x800B1004 (connection refused).  This loop automatically
# restarts LÖVR so the signaling port is always listening.
STOP_REQUESTED=0
RESTART_COUNT=0

_watchdog_stop() {
    STOP_REQUESTED=1
    echo ""
    echo -e "${YELLOW}$(date +%T): [watchdog] Shutdown requested — stopping server.${NC}"
}
trap _watchdog_stop INT TERM
trap '' PIPE          # Ignore SIGPIPE so the watchdog survives lovr crashes

set +eo pipefail   # From here on, non-zero exits must not kill the script

while [ "$STOP_REQUESTED" = "0" ]; do
    # Remove any stale runtime lock left by a previous (un-clean) exit.
    if [ -f "$RUNTIME_STARTED_FILE" ]; then
        rm -f "$RUNTIME_STARTED_FILE" 2>/dev/null || true
    fi

    if [ "$RESTART_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}$(date +%T): [watchdog] Restart #${RESTART_COUNT} — relaunching LOVR...${NC}"
    fi

    "./$(basename "$LOVR_BIN")" "$EXAMPLE_REL_PATH" $DEVICE_PROFILE 2>&1 | tee -a "$LOVR_LOG_FILE"
    LOVR_EXIT=${PIPESTATUS[0]}

    [ "$STOP_REQUESTED" = "1" ] && break

    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo -e "${YELLOW}$(date +%T): [watchdog] LOVR exited (code=$LOVR_EXIT). Restarting in 3 s...${NC}"
    sleep 3
    [ "$STOP_REQUESTED" = "1" ] && break
done

echo ""
echo -e "${GREEN}✓ Server stopped (total restarts: $RESTART_COUNT)${NC}"

# Clean up Xvfb if we started it.
if [ "$XVFB_STARTED" = "1" ] && [ -f "$XVFB_PID_FILE" ]; then
    kill "$(cat "$XVFB_PID_FILE")" 2>/dev/null || true
    rm -f "$XVFB_PID_FILE"
    echo -e "${YELLOW}Xvfb stopped.${NC}"
fi

