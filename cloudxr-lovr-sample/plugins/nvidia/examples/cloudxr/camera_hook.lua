-- SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
-- SPDX-License-Identifier: MIT

-- Camera hook prototype:
-- - Does not ingest webcam frames directly yet.
-- - Emits lightweight camera metadata messages that can be transported over
--   CloudXR opaque data channels for end-to-end plumbing validation.

local CameraHook = {}

local enabled = false
local device = "/dev/video0"
local sendIntervalSeconds = 1.0
local accumulator = 0.0
local pendingMessage = nil
local sentCount = 0

function CameraHook.init()
  enabled = os.getenv("CLOUDXR_CAMERA_HOOK") == "1"
  device = os.getenv("CLOUDXR_CAMERA_DEVICE") or "/dev/video0"
  local intervalEnv = tonumber(os.getenv("CLOUDXR_CAMERA_INTERVAL_SEC"))
  if intervalEnv and intervalEnv > 0 then
    sendIntervalSeconds = intervalEnv
  end

  if enabled then
    print(string.format(
      "Camera hook enabled (device=%s, interval=%.2fs)",
      device,
      sendIntervalSeconds
    ))
  else
    print("Camera hook disabled (set CLOUDXR_CAMERA_HOOK=1 to enable)")
  end
end

function CameraHook.update(dt)
  if not enabled then
    return
  end

  accumulator = accumulator + dt
  if accumulator >= sendIntervalSeconds then
    accumulator = 0.0
    pendingMessage = string.format(
      "camera_hook:device=%s;ts=%d;seq=%d",
      device,
      os.time(),
      sentCount + 1
    )
    sentCount = sentCount + 1
  end
end

function CameraHook.popOutboundMessage()
  local msg = pendingMessage
  pendingMessage = nil
  return msg
end

function CameraHook.getStatusText()
  if not enabled then
    return "Camera hook: off (set CLOUDXR_CAMERA_HOOK=1)"
  end
  return string.format(
    "Camera hook: on (%s), sent=%d",
    device,
    sentCount
  )
end

return CameraHook
