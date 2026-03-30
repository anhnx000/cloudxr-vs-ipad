#!/usr/bin/env python3
"""
Lightweight HTTP API for record control that does not depend on OpenXR/headset.

Endpoints:
  GET  /health
  GET  /record/status
  POST /record/start
  POST /record/stop
"""

from __future__ import annotations

import argparse
import json
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _record_script() -> Path:
    return _repo_root() / "record.sh"


def _run_record_sh(*args: str) -> subprocess.CompletedProcess:
    script = _record_script()
    if not script.exists():
        raise FileNotFoundError(f"record.sh not found at {script}")
    return subprocess.run(
        [str(script), *args],
        cwd=str(_repo_root()),
        capture_output=True,
        text=True,
        check=False,
    )


def _run_record_sh_detached(*args: str) -> int:
    """Run command without capturing output to avoid hanging on background children."""
    script = _record_script()
    if not script.exists():
        raise FileNotFoundError(f"record.sh not found at {script}")
    proc = subprocess.run(
        [str(script), *args],
        cwd=str(_repo_root()),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return proc.returncode


def _status_payload(extra_message: str | None = None) -> Dict[str, Any]:
    proc = _run_record_sh("status")
    output = (proc.stdout or "") + (proc.stderr or "")
    recording = "RECORDING" in output
    payload: Dict[str, Any] = {
        "ok": proc.returncode == 0,
        "status": "recording" if recording else "idle",
        "message": extra_message or output.strip(),
        "raw": output.strip(),
    }
    return payload


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
            self._send_json(200, {"ok": True, "service": "record-control-api"})
            return
        if self.path == "/record/status":
            self._send_json(200, _status_payload())
            return
        self._send_json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/record/start":
            body = self._parse_json_body()
            output = body.get("output") if isinstance(body.get("output"), str) else ""
            cmd = ["start"]
            if output:
                cmd.append(output)
            code = _run_record_sh_detached(*cmd)
            if code != 0:
                # If already recording, treat this as a successful idempotent start.
                status_payload = _status_payload()
                if status_payload.get("status") == "recording":
                    status_payload["ok"] = True
                    status_payload["message"] = "already recording"
                    self._send_json(200, status_payload)
                    return
                self._send_json(500, {"ok": False, "status": "error", "message": "record.sh start failed"})
                return
            payload = _status_payload(extra_message="recording start requested")
            self._send_json(200, payload)
            return

        if self.path == "/record/stop":
            code = _run_record_sh_detached("stop")
            if code != 0:
                self._send_json(500, {"ok": False, "status": "error", "message": "record.sh stop failed"})
                return
            payload = _status_payload(extra_message="recording stop requested")
            self._send_json(200, payload)
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

    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Record control API listening on {args.host}:{args.port}")
    print(f"Using script: {_record_script()}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
