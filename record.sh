#!/usr/bin/env bash
# record.sh — Record the AirPlay stream from iPad to MP4 using GStreamer NVENC.
# No X11 display required.
#
# How it works:
#   1. The iPad mirrors its screen via AirPlay (Control Center → Screen Mirror)
#   2. uxplay receives the AirPlay stream on this Linux server
#   3. GStreamer encodes with NVIDIA NVENC and writes to an MP4 file
#
# Usage:
#   ./record.sh start [output.mp4]
#   ./record.sh stop
#   ./record.sh status

set -euo pipefail

RECORDINGS_DIR="$HOME/work/cloudxr-vs-ipad/recordings"
PID_FILE="/tmp/uxplay_record.pid"
OUTPUT_FILE="/tmp/uxplay_record_output.txt"
STARTED_AT_FILE="/tmp/uxplay_record_started_at.txt"

AIRPLAY_NAME="Linux-AirPlay-Record"
AIRPLAY_PORT=7200
AIRPLAY_MAC="0A:BC:DE:F0:12:34"

mkdir -p "$RECORDINGS_DIR"

usage() {
    cat <<'EOF'
Usage:
  ./record.sh start [output.mp4]   Start recording iPad AirPlay stream
  ./record.sh stop                 Stop recording and finalize MP4 file
  ./record.sh status               Show recording status and saved files
EOF
}

# Build the GStreamer video sink pipeline (no X11 needed).
# Uses NVIDIA NVENC if available, falls back to software x264enc.
build_vs_pipeline() {
    local output="$1"
    local encoder

    if gst-inspect-1.0 nvh264enc &>/dev/null; then
        encoder="nvh264enc"
    else
        encoder="x264enc tune=zerolatency"
    fi

    echo "videoconvert ! ${encoder} ! h264parse ! mp4mux ! filesink location=${output}"
}

start_recording() {
    local output="${1:-}"
    [ -z "$output" ] && output="$RECORDINGS_DIR/ipad_airplay_record_$(date +%Y%m%d_%H%M%S).mp4"

    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Already recording. Run: ./record.sh stop"
        exit 1
    fi

    # Kill any existing uxplay instance to free the port.
    pkill -x uxplay 2>/dev/null || true
    sleep 1

    local vs_pipeline
    vs_pipeline="$(build_vs_pipeline "$output")"

    echo "Starting AirPlay recorder (no display, save to file only)..."
    echo "Encoder: $(echo "$vs_pipeline" | grep -o 'nvh264enc\|x264enc')"
    echo "Output:  $output"

    # Start uxplay in background.
    # -vs  : GStreamer video sink pipeline (write to file, no display)
    # -as 0: disable audio output (audio-only display not needed)
    uxplay \
        -n  "$AIRPLAY_NAME" \
        -nh \
        -p  "$AIRPLAY_PORT" \
        -m  "$AIRPLAY_MAC" \
        -avdec \
        -vp h264parse \
        -vd avdec_h264 \
        -vs "$vs_pipeline" \
        -as 0 \
        -vsync no \
        -fps 30 &

    local pid=$!
    echo "$pid" > "$PID_FILE"
    echo "$output" > "$OUTPUT_FILE"
    date +%s > "$STARTED_AT_FILE"

    echo ""
    echo "Recording started (PID: $pid)"
    echo "On iPad: Control Center → Screen Mirror → $AIRPLAY_NAME"
}

stop_recording() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No recording in progress."
        exit 0
    fi

    local pid output size
    pid=$(cat "$PID_FILE")
    output=$(cat "$OUTPUT_FILE" 2>/dev/null || echo "")

    echo "Stopping recording (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    pkill -x uxplay 2>/dev/null || true

    rm -f "$PID_FILE" "$OUTPUT_FILE" "$STARTED_AT_FILE"
    sleep 1

    if [ -n "$output" ] && [ -f "$output" ]; then
        local bytes
        bytes=$(stat -c%s "$output" 2>/dev/null || echo 0)
        if [ "${bytes:-0}" -eq 0 ]; then
            echo "Saved empty file: $output (0 bytes)"
            echo "Warning: no AirPlay frames were received while recording."
            echo "On iPad, open Control Center -> Screen Mirroring -> Linux-AirPlay-Record."
        else
            size=$(du -sh "$output" | cut -f1)
            echo "Saved: $output ($size)"
        fi
    else
        echo "Recording stopped."
        [ -n "$output" ] && echo "Expected output: $output"
    fi
}

status_recording() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid output
        pid=$(cat "$PID_FILE")
        output=$(cat "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
        echo "RECORDING  (PID: $pid)"
        echo "Output: $output"
        if [ -f "$output" ]; then
            local bytes
            bytes=$(stat -c%s "$output" 2>/dev/null || echo 0)
            if [ "${bytes:-0}" -eq 0 ]; then
                local now started elapsed
                now=$(date +%s)
                started=$(cat "$STARTED_AT_FILE" 2>/dev/null || echo "$now")
                elapsed=$(( now - started ))
                if [ "$elapsed" -ge 5 ]; then
                    echo "Warning: still no video frames after ${elapsed}s."
                    echo "Ensure iPad is mirroring to Linux-AirPlay-Record."
                fi
            fi
        fi
    else
        echo "Not recording."
        rm -f "$PID_FILE" "$OUTPUT_FILE" "$STARTED_AT_FILE" 2>/dev/null || true
    fi

    echo ""
    echo "Files in $RECORDINGS_DIR:"
    ls -lh "$RECORDINGS_DIR"/*.mp4 2>/dev/null || echo "  (none yet)"
}

case "${1:-}" in
    start)  start_recording "${2:-}" ;;
    stop)   stop_recording ;;
    status) status_recording ;;
    *)      usage; exit 1 ;;
esac
