-- recorder.lua  (LOVR 0.18.0 compatible)
-- Capture rendered frames from the LOVR draw loop and encode to MP4 via
-- GStreamer NVENC. No X11 display required.
--
-- Flow:
--   Recorder.start()  → create named pipe + launch gst-launch-1.0 pipeline
--   Recorder.captureFrame(pass, drawFn)  → render to off-screen texture,
--                                           read back pixels, write to pipe
--   Recorder.stop()   → close pipe, GStreamer finalizes the MP4

local Recorder = {}

local isRecording  = false
local pipe         = nil      -- Lua file handle to the named pipe
local captureTexture = nil    -- off-screen LOVR Texture (render target)
local frameWidth   = 1280
local frameHeight  = 720
local pipeFile     = "/tmp/lovr_frames"

Recorder.outputFile = nil

-- ── helpers ──────────────────────────────────────────────────────────────────

local function recordingsDir()
    return (os.getenv("HOME") or "/tmp") .. "/work/cloudxr-vs-ipad/recordings"
end

local function probeEncoder()
    local h = io.popen("gst-inspect-1.0 nvh264enc 2>/dev/null | head -1")
    if h then
        local line = h:read("*l"); h:close()
        if line and line ~= "" then return "nvh264enc" end
    end
    return "x264enc tune=zerolatency"
end

local function buildGstCmd(output)
    local enc = probeEncoder()
    -- fdsrc reads from stdin (fd=0), which is the named pipe via shell redirection.
    -- rawvideoparse: width/height match frameWidth/frameHeight, format=rgba (4 bytes/px)
    return string.format(
        "gst-launch-1.0 -q "
     .. "fdsrc fd=0 "
     .. "! rawvideoparse width=%d height=%d format=rgba framerate=30/1 "
     .. "! videoconvert ! %s ! h264parse ! mp4mux "
     .. "! filesink location=%s",
        frameWidth, frameHeight, enc, output
    )
end

-- ── public API ───────────────────────────────────────────────────────────────

function Recorder.start(outputFile)
    if isRecording then return false, "already recording" end

    os.execute("mkdir -p " .. recordingsDir())
    if not outputFile or outputFile == "" then
        outputFile = recordingsDir() .. "/record_" .. os.date("%Y%m%d_%H%M%S") .. ".mp4"
    end

    -- Create named pipe.
    os.execute("rm -f " .. pipeFile)
    if not os.execute("mkfifo " .. pipeFile) then
        return false, "mkfifo failed: " .. pipeFile
    end

    -- Launch GStreamer reading from named pipe in background.
    -- Shell redirect "< pipeFile" maps pipeFile → fd=0 for gst-launch.
    os.execute(buildGstCmd(outputFile) .. " < " .. pipeFile .. " &")

    -- Brief pause so GStreamer opens the read end before Lua opens write end.
    if lovr and lovr.timer then lovr.timer.sleep(0.3) end

    pipe = io.open(pipeFile, "wb")
    if not pipe then return false, "cannot open pipe for writing" end

    -- Allocate the off-screen render texture once (LOVR 0.18 API).
    -- usage 'render' → can be used as a render target
    -- usage 'transfer' → allows CPU readback via :newReadback()
    if not captureTexture then
        captureTexture = lovr.graphics.newTexture(frameWidth, frameHeight, {
            usage    = { "render", "transfer" },
            mipmaps  = false,
            format   = "rgba8",
        })
    end

    isRecording      = true
    Recorder.outputFile = outputFile
    print("[Recorder] Started → " .. outputFile)
    return true, outputFile
end

function Recorder.stop()
    if not isRecording then return false, "not recording" end

    if pipe then pipe:close(); pipe = nil end
    isRecording = false

    local saved = Recorder.outputFile or ""
    Recorder.outputFile = nil
    print("[Recorder] Stopped → " .. saved)

    os.execute("sleep 1")   -- let GStreamer flush and close the file
    return true, saved
end

function Recorder.isActive()
    return isRecording
end

-- Called from main.lua inside lovr.draw() every frame while recording.
--
-- @param drawFn  function(pass) — draws the scene into the provided Pass.
--                Caller supplies the same rendering calls used for the main pass.
function Recorder.captureFrame(drawFn)
    if not isRecording or not pipe or not captureTexture then return end

    -- 1. Create a new render Pass targeting our off-screen texture (LOVR 0.18).
    local capturePass = lovr.graphics.newPass(captureTexture)

    -- 2. Let the caller draw the scene into the capture pass.
    if drawFn then
        drawFn(capturePass)
    end

    -- 3. Submit the capture pass to the GPU queue.
    lovr.graphics.submit(capturePass)

    -- 4. Read the texture back to CPU synchronously.
    --    readback:wait() stalls until GPU finishes — acceptable for recording.
    local readback = captureTexture:newReadback()
    readback:wait()

    -- 5. Get raw pixel bytes from the readback image and write to the pipe.
    --    GStreamer rawvideoparse expects RGBA8, 4 bytes/pixel, row-major.
    local image = readback:getImage()
    if image then
        local blob = image:getBlob()
        pipe:write(blob:getString())
        pipe:flush()
    end
end

return Recorder
