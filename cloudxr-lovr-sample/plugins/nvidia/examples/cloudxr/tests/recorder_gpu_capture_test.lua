-- recorder_gpu_capture_test.lua
-- Purpose: simulate GPU-processed frame recording path in recorder.lua.

local scriptPath = arg and arg[0] or ""
local testsDir = scriptPath:match("^(.*)/[^/]+$") or "."
local moduleDir = testsDir:gsub("/tests$", "/")
package.path = moduleDir .. "?.lua;" .. package.path

local function assertEquals(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertEquals failed") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function assertTrue(value, msg)
  if not value then
    error(msg or "assertTrue failed")
  end
end

local calls = {
  execute = {},
  popen = {},
  submitCount = 0,
  drawCount = 0,
  wroteBytes = 0,
  pipeClosed = false
}

local originalOsExecute = os.execute
local originalIoPopen = io.popen
local originalIoOpen = io.open
local originalLovr = _G.lovr

local pipeHandle = {
  write = function(_, data)
    calls.wroteBytes = calls.wroteBytes + #data
  end,
  flush = function() end,
  close = function()
    calls.pipeClosed = true
  end
}

os.execute = function(cmd)
  calls.execute[#calls.execute + 1] = cmd
  return true
end

io.popen = function(cmd)
  calls.popen[#calls.popen + 1] = cmd
  return {
    read = function(_, mode)
      if mode == "*l" then
        return "Factory Details: nvh264enc"
      end
      return nil
    end,
    close = function() end
  }
end

io.open = function(path, mode)
  if path == "/tmp/lovr_frames" and mode == "wb" then
    return pipeHandle
  end
  return nil
end

_G.lovr = {
  timer = {
    sleep = function() end
  },
  graphics = {
    newTexture = function(_, _, _)
      return {
        newReadback = function()
          return {
            wait = function() end,
            getImage = function()
              return {
                getBlob = function()
                  return {
                    getString = function()
                      -- Simulate one GPU-rendered RGBA frame payload.
                      return string.rep("A", 128)
                    end
                  }
                end
              }
            end
          }
        end
      }
    end,
    newPass = function(texture)
      return { target = texture }
    end,
    submit = function(_)
      calls.submitCount = calls.submitCount + 1
    end
  }
}

local Recorder = require("recorder")

local ok, output = Recorder.start("/tmp/test-record.mp4")
assertTrue(ok, "Recorder.start should succeed")
assertEquals(output, "/tmp/test-record.mp4", "Output path should match explicit path")

Recorder.captureFrame(function(_)
  calls.drawCount = calls.drawCount + 1
end)

assertEquals(calls.drawCount, 1, "Draw callback should run exactly once")
assertEquals(calls.submitCount, 1, "One capture pass should be submitted")
assertTrue(calls.wroteBytes > 0, "Captured frame bytes should be written to pipe")

local stopOk, savedPath = Recorder.stop()
assertTrue(stopOk, "Recorder.stop should succeed")
assertEquals(savedPath, "/tmp/test-record.mp4", "Saved path should be returned on stop")
assertTrue(calls.pipeClosed, "Pipe should be closed on stop")

-- Verify we created FIFO and launched encoder pipeline.
local joinedExec = table.concat(calls.execute, "\n")
assertTrue(joinedExec:find("mkfifo /tmp/lovr_frames", 1, true) ~= nil, "mkfifo command should be executed")
assertTrue(joinedExec:find("gst-launch-1.0", 1, true) ~= nil, "GStreamer command should be executed")

-- Cleanup globals.
os.execute = originalOsExecute
io.popen = originalIoPopen
io.open = originalIoOpen
_G.lovr = originalLovr

print("PASS recorder_gpu_capture_test.lua")
