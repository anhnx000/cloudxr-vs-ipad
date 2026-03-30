#!/usr/bin/env bash
# record.sh — Start/stop AirPlay video recording via GStreamer pipeline.
# Usage:
#   ./record.sh start [output_file.mp4]
#   ./record.sh stop
#   ./record.sh status

set -euo pipefail

RECORDINGS_DIR="$HOME/work/cloudxr-vs-ipad/recordings"
PID_FILE="/tmp/uxplay_record.pid"
PIPELINE_PID_FILE="/tmp/gst_record.pid"
UXPLAY_PID_FILE="/tmp/uxplay_preview.pid"

mkdir -p "$RECORDINGS_DIR"

usage() {
    cat <<'EOF'
Usage:
  ./record.sh start [output.mp4]   Start recording (default: recordings/record_<timestamp>.mp4)
  ./record.sh stop                 Stop recording and finalize file
  ./record.sh status               Show current recording status
EOF
}

airplay_name="Linux-AirPlay-Record"
airplay_port=7200
airplay_mac="0A:BC:DE:F0:12:34"

start_recording() {
    local output="${1:-}"
    if [ -z "$output" ]; then
        output="$RECORDINGS_DIR/record_$(date +%Y%m%d_%H%M%S).mp4"
    fi

    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Already recording. Stop first with: ./record.sh stop"
        exit 1
    fi

    pkill uxplay 2>/dev/null || true
    sleep 1

    echo "Starting AirPlay receiver with recording pipeline..."
    echo "Output: $output"

    # GStreamer pipeline:
    #   appsrc (AirPlay video) → h264parse → avdec_h264 → videoconvert
    #     → tee → branch 1: ximagesink (preview on screen)
    #           → branch 2: x264enc → mp4mux → filesink (save file)
    GST_VIDEO_PIPELINE="appsrc name=video_source ! queue ! h264parse ! avdec_h264 ! videoconvert ! tee name=t \
t. ! queue ! ximagesink sync=false \
t. ! queue ! x264enc tune=zerolatency ! mp4mux ! filesink location=\"$output\""

    uxplay \
        -n "$airplay_name" \
        -nh \
        -p "$airplay_port" \
        -m "$airplay_mac" \
        -avdec \
        -vp h264parse \
        -vd avdec_h264 \
        -vs "ximagesink" \
        -a \
        -vsync no \
        -fps 30 &

    UXPLAY_PID=$!
    echo "$UXPLAY_PID" > "$UXPLAY_PID_FILE"

    echo "Recording started (PID: $UXPLAY_PID)"
    echo "Output file: $output"
    echo "$output" > /tmp/uxplay_record_output.txt
    echo "$UXPLAY_PID" > "$PID_FILE"
    echo "Connect iPad to AirPlay: $airplay_name"
}

stop_recording() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No recording in progress."
        exit 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    local output=""
    [ -f /tmp/uxplay_record_output.txt ] && output=$(cat /tmp/uxplay_record_output.txt)

    echo "Stopping recording (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    pkill uxplay 2>/dev/null || true

    rm -f "$PID_FILE" /tmp/uxplay_record_output.txt "$UXPLAY_PID_FILE"

    sleep 1

    if [ -n "$output" ] && [ -f "$output" ]; then
        local size
        size=$(du -sh "$output" | cut -f1)
        echo "Recording saved: $output ($size)"
    else
        echo "Recording stopped."
        [ -n "$output" ] && echo "Output file: $output"
    fi
}

status_recording() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid output
        pid=$(cat "$PID_FILE")
        output=$(cat /tmp/uxplay_record_output.txt 2>/dev/null || echo "unknown")
        echo "RECORDING in progress (PID: $pid)"
        echo "Output: $output"
    else
        echo "Not recording."
        rm -f "$PID_FILE" /tmp/uxplay_record_output.txt 2>/dev/null || true
    fi

    echo ""
    echo "Recordings in $RECORDINGS_DIR:"
    ls -lh "$RECORDINGS_DIR"/*.mp4 2>/dev/null || echo "  (none)"
}

case "${1:-}" in
    start)
        start_recording "${2:-}"
        ;;
    stop)
        stop_recording
        ;;
    status)
        status_recording
        ;;
    *)
        usage
        exit 1
        ;;
esac
