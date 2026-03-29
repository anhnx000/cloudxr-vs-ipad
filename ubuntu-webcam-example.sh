#!/usr/bin/env bash
set -euo pipefail

# Simple Ubuntu webcam prototype using GStreamer + V4L2.
# Modes:
#   test                          - capture a short burst to fakesink
#   preview                       - show local webcam preview window
#   stream <host> <port>          - send webcam over UDP (RTP/JPEG)
#   receive <port>                - receive and display UDP stream
#   record <file.webm> [seconds]  - record webcam to WebM file
#   record-screen <file.webm> [seconds] - record desktop screen to WebM file

MODE="${1:-}"
DEVICE="${DEVICE:-/dev/video0}"
WIDTH="${WIDTH:-640}"
HEIGHT="${HEIGHT:-480}"
FPS="${FPS:-30}"

usage() {
  cat <<'EOF'
Usage:
  ./ubuntu-webcam-example.sh test
  ./ubuntu-webcam-example.sh preview
  ./ubuntu-webcam-example.sh stream <host> <port>
  ./ubuntu-webcam-example.sh receive <port>
  ./ubuntu-webcam-example.sh record output.webm [seconds]
  ./ubuntu-webcam-example.sh record-screen output.webm [seconds]

Optional environment variables:
  DEVICE=/dev/video0
  WIDTH=640
  HEIGHT=480
  FPS=30
EOF
}

require_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1"
    exit 1
  }
}

require_bin gst-launch-1.0

if [[ ! -e "$DEVICE" ]]; then
  echo "Camera device not found: $DEVICE"
  exit 1
fi

run_with_optional_timeout() {
  local duration="${1:-}"
  shift
  if [[ -n "$duration" ]]; then
    timeout --signal=INT --kill-after=3 "${duration}" "$@" || true
  else
    "$@"
  fi
}

case "$MODE" in
  test)
    echo "Testing camera capture from $DEVICE ..."
    gst-launch-1.0 -v \
      v4l2src device="$DEVICE" num-buffers=90 ! \
      video/x-raw,width="$WIDTH",height="$HEIGHT",framerate="$FPS"/1 ! \
      videoconvert ! fakesink
    ;;

  preview)
    echo "Opening local webcam preview from $DEVICE ..."
    gst-launch-1.0 -v \
      v4l2src device="$DEVICE" ! \
      video/x-raw,width="$WIDTH",height="$HEIGHT",framerate="$FPS"/1 ! \
      videoconvert ! autovideosink sync=false
    ;;

  stream)
    HOST="${2:-}"
    PORT="${3:-5000}"
    if [[ -z "$HOST" ]]; then
      echo "Missing host. Example: ./ubuntu-webcam-example.sh stream 192.168.0.20 5000"
      exit 1
    fi
    echo "Streaming webcam to $HOST:$PORT (RTP/JPEG over UDP) ..."
    gst-launch-1.0 -v \
      v4l2src device="$DEVICE" ! \
      video/x-raw,width="$WIDTH",height="$HEIGHT",framerate="$FPS"/1 ! \
      videoconvert ! jpegenc ! rtpjpegpay ! \
      udpsink host="$HOST" port="$PORT"
    ;;

  receive)
    PORT="${2:-5000}"
    echo "Receiving webcam stream on UDP port $PORT ..."
    gst-launch-1.0 -v \
      udpsrc port="$PORT" caps="application/x-rtp,media=video,encoding-name=JPEG,payload=26" ! \
      rtpjpegdepay ! jpegdec ! videoconvert ! autovideosink sync=false
    ;;

  record)
    OUTPUT="${2:-}"
    DURATION="${3:-}"
    if [[ -z "$OUTPUT" ]]; then
      echo "Missing output path. Example: ./ubuntu-webcam-example.sh record /tmp/cam.webm 10s"
      exit 1
    fi
    mkdir -p "$(dirname "$OUTPUT")"
    echo "Recording webcam from $DEVICE to $OUTPUT ..."
    run_with_optional_timeout "$DURATION" \
      gst-launch-1.0 -e -v \
      v4l2src device="$DEVICE" ! \
      video/x-raw,width="$WIDTH",height="$HEIGHT",framerate="$FPS"/1 ! \
      videoconvert ! queue ! \
      vp8enc deadline=1 cpu-used=8 target-bitrate=2000000 ! \
      webmmux ! filesink location="$OUTPUT"
    echo "Saved: $OUTPUT"
    ;;

  record-screen)
    OUTPUT="${2:-}"
    DURATION="${3:-}"
    if [[ -z "$OUTPUT" ]]; then
      echo "Missing output path. Example: ./ubuntu-webcam-example.sh record-screen /tmp/screen.webm 10s"
      exit 1
    fi
    if [[ -z "${DISPLAY:-}" ]]; then
      echo "DISPLAY is not set. Run this mode in a desktop session."
      exit 1
    fi
    mkdir -p "$(dirname "$OUTPUT")"
    echo "Recording screen (:${DISPLAY}) to $OUTPUT ..."
    run_with_optional_timeout "$DURATION" \
      gst-launch-1.0 -e -v \
      ximagesrc use-damage=0 ! \
      video/x-raw,framerate="$FPS"/1 ! \
      videoconvert ! queue ! \
      vp8enc deadline=1 cpu-used=8 target-bitrate=3000000 ! \
      webmmux ! filesink location="$OUTPUT"
    echo "Saved: $OUTPUT"
    ;;

  *)
    usage
    exit 1
    ;;
esac

