#!/usr/bin/env python3
"""
Lightweight HTTP API for record control.

This API controls the LÖVR recorder path (post-CloudXR render output) using
local command/status files written/read by the running LÖVR process.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _command_file() -> Path:
    return Path("/tmp/cloudxr_lovr_record_cmd.txt")


def _status_file() -> Path:
    return Path("/tmp/cloudxr_lovr_record_status.txt")


def _camera_state_file() -> Path:
    return Path("/tmp/cloudxr_ipad_camera_state.json")


def _camera_frames_root() -> Path:
    root = _repo_root() / "recordings" / "ipad_camera_frames"
    root.mkdir(parents=True, exist_ok=True)
    return root


CAMERA_STATE_LOCK = threading.RLock()
CAMERA_STATE: Dict[str, Any] = {
    "active": False,
    "session_id": "",
    "frames_dir": "",
    "frame_count": 0,
    "fps": 10,
    "output": "",
}


def _read_status_payload() -> Dict[str, Any]:
    status_path = _status_file()
    if not status_path.exists():
        return {
            "ok": False,
            "status": "unknown",
            "source": "unknown",
            "output": "",
            "message": "Recorder status is not available yet.",
            "raw": "",
            "ts": "0",
        }

    values: Dict[str, str] = {}
    for line in status_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            values[k.strip()] = v.strip()

    return {
        "ok": values.get("ok", "0") == "1",
        "status": values.get("status", "unknown"),
        "source": values.get("source", "unknown"),
        "output": values.get("output", ""),
        "message": values.get("message", ""),
        "raw": status_path.read_text(encoding="utf-8", errors="ignore"),
        "ts": values.get("ts", "0"),
    }


def _write_command(command: str, source: str, output: str) -> None:
    payload = f"{command}|source={source}|output={output}"
    _command_file().write_text(payload, encoding="utf-8")


def _wait_for_status_change(prev_ts: str, timeout_sec: float = 4.0) -> Dict[str, Any]:
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        status = _read_status_payload()
        if status.get("ts") != prev_ts and status.get("ts") != "0":
            return status
        time.sleep(0.12)
    return _read_status_payload()


def _default_output_for_source(source: str) -> str:
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    name = "cloudxr_from_ipad" if source == "ipad" else "cloudxr_from_ubuntu"
    return str(_repo_root() / "recordings" / f"{name}_{ts}.mp4")


def _default_camera_output() -> str:
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return str(_repo_root() / "recordings" / f"camera_from_ipad_{ts}.mp4")


def _save_camera_state() -> None:
    _camera_state_file().write_text(json.dumps(CAMERA_STATE, ensure_ascii=True), encoding="utf-8")


def _load_camera_state() -> None:
    path = _camera_state_file()
    if not path.exists():
        return
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            CAMERA_STATE.update(loaded)
    except Exception:
        pass


def _pick_gst_encoder() -> list[str]:
    # Prefer GPU encoder when available.
    checks = [
        (["nvh264enc"], "nvh264enc"),
        (["x264enc", "tune=zerolatency"], "x264enc"),
        (["openh264enc"], "openh264enc"),
    ]
    for cmd, probe in checks:
        probe_proc = subprocess.run(
            ["gst-inspect-1.0", probe],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if probe_proc.returncode == 0:
            return cmd
    return []


def _camera_status_payload(message: str = "") -> Dict[str, Any]:
    with CAMERA_STATE_LOCK:
        return {
            "ok": True,
            "active": bool(CAMERA_STATE.get("active")),
            "session_id": CAMERA_STATE.get("session_id", ""),
            "frame_count": int(CAMERA_STATE.get("frame_count", 0)),
            "fps": int(CAMERA_STATE.get("fps", 10)),
            "output": CAMERA_STATE.get("output", ""),
            "message": message,
        }


def _camera_start(fps: int = 10, output: str = "") -> Dict[str, Any]:
    with CAMERA_STATE_LOCK:
        if CAMERA_STATE.get("active"):
            return _camera_status_payload("camera session already active")

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        session_id = f"cam_{ts}"
        frames_dir = _camera_frames_root() / session_id
        frames_dir.mkdir(parents=True, exist_ok=True)
        CAMERA_STATE.update(
            {
                "active": True,
                "session_id": session_id,
                "frames_dir": str(frames_dir),
                "frame_count": 0,
                "fps": max(1, min(int(fps), 30)),
                "output": output or _default_camera_output(),
            }
        )
        _save_camera_state()
        return _camera_status_payload("camera session started")


def _camera_add_frame(frame_bytes: bytes) -> Dict[str, Any]:
    with CAMERA_STATE_LOCK:
        if not CAMERA_STATE.get("active"):
            return {"ok": False, "message": "camera session is not active"}
        frames_dir = Path(str(CAMERA_STATE.get("frames_dir", "")))
        if not frames_dir.exists():
            return {"ok": False, "message": "camera frames directory missing"}
        index = int(CAMERA_STATE.get("frame_count", 0))
        target = frames_dir / f"frame_{index:06d}.jpg"
        target.write_bytes(frame_bytes)
        CAMERA_STATE["frame_count"] = index + 1
        _save_camera_state()
        return {"ok": True, "frame_count": CAMERA_STATE["frame_count"]}


def _camera_stop() -> Dict[str, Any]:
    with CAMERA_STATE_LOCK:
        active = bool(CAMERA_STATE.get("active"))
        frame_count = int(CAMERA_STATE.get("frame_count", 0))
        fps = int(CAMERA_STATE.get("fps", 10))
        output = str(CAMERA_STATE.get("output", ""))
        session_id = str(CAMERA_STATE.get("session_id", ""))
        frames_dir = Path(str(CAMERA_STATE.get("frames_dir", "")))
        CAMERA_STATE["active"] = False
        _save_camera_state()

    if not active:
        return {"ok": True, "status": "idle", "message": "camera session already idle", "output": output}

    if frame_count <= 0:
        return {"ok": False, "status": "error", "message": "no camera frames received", "output": output}

    encoder = _pick_gst_encoder()
    if not encoder:
        return {"ok": False, "status": "error", "message": "no H264 GStreamer encoder found", "output": output}

    if not frames_dir.exists():
        return {"ok": False, "status": "error", "message": "camera frames directory missing", "output": output}

    gst_cmd = [
        "gst-launch-1.0",
        "-e",
        "multifilesrc",
        f"location={frames_dir}/frame_%06d.jpg",
        "index=0",
        f"caps=image/jpeg,framerate={fps}/1",
        "!",
        "jpegdec",
        "!",
        "videoconvert",
        "!",
        *encoder,
        "!",
        "h264parse",
        "!",
        "mp4mux",
        "!",
        "filesink",
        f"location={output}",
    ]
    proc = subprocess.run(gst_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    if proc.returncode != 0:
        return {
            "ok": False,
            "status": "error",
            "message": (proc.stderr or proc.stdout or "gst encode failed").strip()[:1200],
            "output": output,
        }

    # Clean temporary frames on successful mux.
    shutil.rmtree(frames_dir, ignore_errors=True)
    return {
        "ok": True,
        "status": "idle",
        "message": f"camera recording saved ({frame_count} frames)",
        "output": output,
        "session_id": session_id,
        "frame_count": frame_count,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "CloudXRRecordControl/1.0"

    def _send_json(self, status: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _parse_json_body(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        try:
            raw = self.rfile.read(length).decode("utf-8")
            data = json.loads(raw)
            return data if isinstance(data, dict) else {}
        except Exception:
            return {}

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            camera = _camera_status_payload()
            self._send_json(200, {"ok": True, "service": "record-control-api", "camera_active": camera["active"]})
            return
        if self.path == "/record/status":
            self._send_json(200, _read_status_payload())
            return
        if self.path == "/camera/status":
            self._send_json(200, _camera_status_payload())
            return
        self._send_json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/record/start":
            body = self._parse_json_body()
            output = body.get("output") if isinstance(body.get("output"), str) else ""
            source = body.get("source") if isinstance(body.get("source"), str) else ""
            if not source:
                source = "ipad"
            if not output:
                output = _default_output_for_source(source)
            prev = _read_status_payload()
            _write_command("start", source, output)
            payload = _wait_for_status_change(str(prev.get("ts", "0")))
            if payload.get("status") == "recording":
                self._send_json(200, payload)
            else:
                self._send_json(500, payload)
            return

        if self.path == "/record/stop":
            prev = _read_status_payload()
            _write_command("stop", "ipad", "")
            payload = _wait_for_status_change(str(prev.get("ts", "0")))
            if payload.get("status") in {"idle", "not_recording"}:
                self._send_json(200, payload)
            else:
                self._send_json(500, payload)
            return

        if self.path == "/camera/start":
            body = self._parse_json_body()
            fps = int(body.get("fps", 10)) if isinstance(body.get("fps"), int) else 10
            output = body.get("output") if isinstance(body.get("output"), str) else ""
            self._send_json(200, _camera_start(fps=fps, output=output))
            return

        if self.path == "/camera/frame":
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0:
                self._send_json(400, {"ok": False, "message": "empty frame payload"})
                return
            frame = self.rfile.read(length)
            result = _camera_add_frame(frame)
            self._send_json(200 if result.get("ok") else 400, result)
            return

        if self.path == "/camera/stop":
            payload = _camera_stop()
            self._send_json(200 if payload.get("ok") else 500, payload)
            return

        self._send_json(404, {"ok": False, "error": "not_found"})

    def log_message(self, fmt: str, *args: Any) -> None:
        # Keep logs concise for long-running service.
        print(f"[record-api] {self.address_string()} - {fmt % args}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=49080)
    args = parser.parse_args()

    _load_camera_state()
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Record control API listening on {args.host}:{args.port}")
    print(f"Command file: {_command_file()}")
    print(f"Status file: {_status_file()}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
