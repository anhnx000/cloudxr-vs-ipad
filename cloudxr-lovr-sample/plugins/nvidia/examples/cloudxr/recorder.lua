-- recorder.lua
-- Capture rendered frames from the LOVR render loop and pipe them to GStreamer
-- for encoding to MP4, without requiring an X11 display.
--
-- How it works:
--   1. On record_start: open a named pipe (/tmp/lovr_frames) and launch
--      a GStreamer pipeline that reads raw RGB frames from that pipe,
--      encodes with NVENC (or x264), and muxes into MP4.
--   2. Every draw frame: render the scene to an off-screen Canvas, read
--      back the raw pixels, and write them into the pipe.
--   3. On record_stop: close the pipe so GStreamer finishes the file.

local Recorder = {}

local isRecording = false
local pipe = nil           -- File handle for the named pipe
local frameWidth  = 1280
local frameHeight = 720
local pipeFile = "/tmp/lovr_frames"
local gstPid = nil

local function getRecordingsDir()
    local home = os.getenv("HOME") or "/tmp"
    return home .. "/work/cloudxr-vs-ipad/recordings"
end

local function buildGstCmd(outputFile)
    local w, h = frameWidth, frameHeight
    local encoder = "x264enc tune=zerolatency"

    -- Prefer NVIDIA hardware encoder if available.
    local probe = io.popen("gst-inspect-1.0 nvh264enc 2>/dev/null | head -1")
    if probe then
        local line = probe:read("*l")
        probe:close()
        if line and line ~= "" then
            encoder = "nvh264enc"
        end
    end

    -- GStreamer pipeline: read raw RGB24 frames from named pipe → encode → MP4
    return string.format(
        "gst-launch-1.0 -q fdsrc fd=0 " ..
        "! rawvideoparse width=%d height=%d format=rgbx framerate=30/1 " ..
        "! videoconvert ! %s ! h264parse ! mp4mux ! filesink location=%s",
        w, h, encoder, outputFile
    )
end

-- Start recording to the given output file path.
-- Called from cloudxr_manager.lua when cmd:record_start is received.
function Recorder.start(outputFile)
    if isRecording then
        return false, "already recording"
    end

    local dir = getRecordingsDir()
    os.execute("mkdir -p " .. dir)

    if not outputFile or outputFile == "" then
        outputFile = dir .. "/record_" ..
            os.date("%Y%m%d_%H%M%S") .. ".mp4"
    end

    -- Create named pipe.
    os.execute("rm -f " .. pipeFile)
    local ok = os.execute("mkfifo " .. pipeFile)
    if not ok then
        return false, "failed to create named pipe " .. pipeFile
    end

    -- Launch GStreamer reading from the named pipe in the background.
    local gstCmd = buildGstCmd(outputFile) ..
        " < " .. pipeFile .. " &"
    os.execute(gstCmd)

    -- Small delay so GStreamer opens the pipe before LOVR writes to it.
    -- lovr.timer.sleep is available if this file is loaded inside LOVR.
    if lovr and lovr.timer then
        lovr.timer.sleep(0.3)
    end

    -- Open the pipe for writing raw frame data.
    pipe = io.open(pipeFile, "wb")
    if not pipe then
        return false, "failed to open named pipe for writing"
    end

    isRecording = true
    Recorder.outputFile = outputFile
    print("[Recorder] Started → " .. outputFile)
    return true, outputFile
end

-- Stop recording. Close the pipe so GStreamer finalizes the MP4.
function Recorder.stop()
    if not isRecording then
        return false, "not recording"
    end

    if pipe then
        pipe:close()
        pipe = nil
    end

    isRecording = false
    local saved = Recorder.outputFile or ""
    Recorder.outputFile = nil
    print("[Recorder] Stopped → " .. saved)

    -- Give GStreamer a moment to flush and close the file.
    os.execute("sleep 1")

    return true, saved
end

-- Returns true if currently recording.
function Recorder.isActive()
    return isRecording
end

-- Called from lovr.draw(pass) every frame while recording.
-- Renders the scene to an off-screen canvas and writes raw pixels to the pipe.
function Recorder.captureFrame(drawCallback)
    if not isRecording or not pipe then return end

    -- Lazy-create the off-screen canvas at the configured resolution.
    if not Recorder._canvas then
        Recorder._canvas = lovr.graphics.newCanvas(frameWidth, frameHeight, {
            format = "rgba8",
            depth  = true,
        })
    end

    -- Render the scene into the off-screen canvas.
    Recorder._canvas:renderTo(function()
        if drawCallback then
            drawCallback()
        end
    end)

    -- Read the canvas pixels back to CPU (returns a TextureData / Blob).
    local imageData = Recorder._canvas:newImageData()
    if imageData then
        -- Write raw pixel bytes (RGBA8, 4 bytes per pixel) to the pipe.
        -- GStreamer rawvideoparse expects "rgbx" which is RGBA8 packed.
        local blob = imageData:getBlob()
        pipe:write(blob:getString())
        pipe:flush()
    end
end

return Recorder
