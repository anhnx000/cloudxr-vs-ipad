-- cloudxr_manager_record_feedback_test.lua
-- Purpose: verify record command always gets explicit feedback status.

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

local sentMessages = {}
local inboundMessages = {}

local fakeNv = {
  OPAQUE_DATA_CHANNEL_STATUS = { CONNECTED = 1, DISCONNECTED = 2 }
}

function fakeNv.getOpaqueDataChannelState()
  return fakeNv.OPAQUE_DATA_CHANNEL_STATUS.CONNECTED
end

function fakeNv.receiveOpaqueDataChannel()
  if #inboundMessages == 0 then
    return nil
  end
  local msg = inboundMessages[1]
  table.remove(inboundMessages, 1)
  return msg
end

function fakeNv.sendOpaqueDataChannel(msg)
  sentMessages[#sentMessages + 1] = msg
  return true
end

local fakeRecorder = {
  active = false
}

function fakeRecorder.isActive()
  return fakeRecorder.active
end

function fakeRecorder.start()
  return false, "gpu encode failed"
end

function fakeRecorder.stop()
  return true, "/tmp/fake.mp4"
end

package.loaded["cloudxr_manager"] = nil
package.preload["nvidia"] = function()
  return fakeNv
end
package.preload["recorder"] = function()
  return fakeRecorder
end

local CloudXRManager = require("cloudxr_manager")
assertTrue(CloudXRManager.init(), "CloudXRManager.init should load fake nvidia plugin")

inboundMessages[#inboundMessages + 1] = "cmd:record_start"
CloudXRManager.update()

assertTrue(#sentMessages >= 1, "Expected at least one outbound status message")
assertTrue(sentMessages[#sentMessages]:find("status:recording_error:", 1, true) == 1,
  "Expected detailed recording error status")
assertTrue(sentMessages[#sentMessages]:find("gpu encode failed", 1, true) ~= nil,
  "Expected recorder failure reason in payload")

-- Validate already-recording explicit feedback too.
fakeRecorder.active = true
inboundMessages[#inboundMessages + 1] = "cmd:record_start"
CloudXRManager.update()
assertEquals(sentMessages[#sentMessages], "status:already_recording", "Expected already-recording status")

print("PASS cloudxr_manager_record_feedback_test.lua")
