-- SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
-- SPDX-License-Identifier: MIT

-- Models are provided by immersive-web under the MIT license
-- https://github.com/immersive-web/webxr-input-profiles/blob/main/packages/assets/LICENSE.md
-- https://github.com/immersive-web/webxr-input-profiles/tree/main/packages/assets/profiles/meta-quest-touch-plus

print("NVIDIA CloudXR Plugin Example")

-- Import our custom modules
-- These handle different aspects of the CloudXR integration
local CloudXRManager = require('cloudxr_manager')  -- Manages CloudXR runtime and opaque data channels
local HeadsetManager = require('headset_manager')  -- Manages OpenXR headset initialization
local Renderer = require('renderer')               -- Handles rendering of VR content and data
local AudioManager = require('audio_manager')      -- Manages audio playback triggered by hand gestures
local CameraHook = require('camera_hook')          -- Prototype bridge for camera metadata plumbing
local OPAQUE_RETRY_INTERVAL_SEC = 2.0
local REQUIRE_HEADSET = os.getenv("CXR_REQUIRE_HEADSET") == "1"

local headsetInitialized = false
local opaqueChannelInitialized = false
local audioInitAttempted = false
local cameraHookInitialized = false
local appReadyLogged = false
local nextOpaqueRetryAt = 0

-- Parse command line arguments to check for special flags
-- This allows users to modify behavior without changing code
local function parseArgs()
    local args = {}
    
    -- Look for command line flags (arguments starting with --)
    -- This is useful for development and testing different configurations
    for i = 1, #arg do
        local argStr = arg[i]
        if argStr:sub(1, 2) == "--" and not argStr:find("=") then
            -- Extract the flag name (remove -- prefix)
            local flagName = argStr:sub(3)
            args[flagName] = true
            print("Flag enabled:", flagName)
        end
    end
    
    return args
end

-- LÖVR load function - called once when the application starts
-- This is where we initialize all our modules in the correct order
function lovr.load(args)
    print("Loading CloudXR manager...")    
    
    -- Parse command line arguments first
    local parsedArgs = parseArgs()
    
    -- Initialize the CloudXR plugin (loads the nvidia.dll/nvidia.so library)
    if not CloudXRManager.init(parsedArgs) then
        print("Failed to initialize CloudXR")
        return
    end
    
    -- Initialize CloudXR runtime service (unless using system runtime)
    -- This must happen BEFORE OpenXR initialization
    if not parsedArgs.use_system_runtime then       
        if CloudXRManager.initRuntime(parsedArgs) then
            print("CloudXR Runtime initialized successfully")
        else
            print("Failed to initialize CloudXR Runtime")
        end
    else
        print("Skipping CloudXR Runtime initialization (--use_system_runtime flag detected)")
    end
    
    -- iPad-centric default: keep CloudXR server alive without requiring headset.
    -- Set CXR_REQUIRE_HEADSET=1 to restore strict headset-dependent behavior.
    if REQUIRE_HEADSET then
        if HeadsetManager.init() then
            headsetInitialized = true
        else
            print("Headset unavailable at startup; running and retrying without exiting.")
        end
    else
        print("Running in headset-independent mode for iPad workflow (CXR_REQUIRE_HEADSET != 1).")
    end

    -- Opaque channel is retried independently from headset lifecycle.
    if CloudXRManager.initOpaqueDataChannel() then
        opaqueChannelInitialized = true
    else
        print("Opaque Data Channel not ready yet; will retry initialization.")
    end

    if not cameraHookInitialized then
        CameraHook.init()
        cameraHookInitialized = true
    end

    if REQUIRE_HEADSET and headsetInitialized and not audioInitAttempted then
        audioInitAttempted = true
        if not AudioManager.init() then
            print("Failed to initialize Audio Manager")
            -- Continue anyway, audio is not critical
        end
    end

    if opaqueChannelInitialized then
        appReadyLogged = true
        print("Application initialized successfully")
    end
end

-- LÖVR quit function - called when the application is shutting down
-- Clean up resources in reverse order of initialization
function lovr.quit()
    print("Cleaning up application...")
    
    -- Clean up audio manager
    if AudioManager then
        AudioManager.cleanup()
    end
    
    -- Clean up headset and OpenXR resources first
    HeadsetManager.cleanup()
    
    -- Clean up CloudXR resources (runtime service and opaque data channels)
    if CloudXRManager then
        CloudXRManager.destroy()
    end
    
    print("Cleanup complete")
end 

-- LÖVR draw function - called every frame to render the VR scene
-- This is where we draw all the VR content that gets streamed to the headset
function lovr.draw(pass)
    local lastReceivedData = nil
    local cameraStatusText = nil
    
    -- Get any data received from the headset via opaque data channels
    -- This could be custom sensor data, user input, or other information
    if CloudXRManager then
        lastReceivedData = CloudXRManager.getLastReceivedData()
        cameraStatusText = CameraHook.getStatusText()
        -- Render any opaque data (like hand tracking data) if available
        Renderer.drawOpaqueData(pass, lastReceivedData, cameraStatusText)
    end
    
    local headsetActive = REQUIRE_HEADSET and HeadsetManager.isActive()
    if headsetActive then
        -- Get controller models for rendering
        local models = HeadsetManager.getModels()

        -- Draw hand joints and controller models in the VR space
        Renderer.drawHandJoints(pass, lastReceivedData)
        Renderer.drawControllers(pass, models)
    
        -- Reset color to white for subsequent rendering
        pass:setColor(1, 1, 1, 1)

        -- If recording is active, capture this frame into the GStreamer pipe.
        -- Recorder.captureFrame creates its own off-screen Pass and calls
        -- the drawFn with that pass — no X11 or window required.
        if CloudXRManager and CloudXRManager.isRecording() then
            CloudXRManager.captureFrame(function(capturePass)
                Renderer.drawOpaqueData(capturePass, lastReceivedData, cameraStatusText)
                Renderer.drawHandJoints(capturePass, lastReceivedData)
                Renderer.drawControllers(capturePass, models)
            end)
        end
    else
        pass:text("CloudXR server running (headset-independent mode)", 0, 1.2, -2.5, .35)
    end
end

-- LÖVR update function - called every frame for game logic and updates
-- This is where we handle input, update state, and process opaque data
function lovr.update(dt)
    -- Check for Enter key press to exit the application
    if lovr.system and lovr.system.isKeyDown('return') then
        print("Enter key pressed - exiting application")
        lovr.event.quit()
        return
    end

    local now = (lovr.timer and lovr.timer.getTime and lovr.timer.getTime()) or 0

    if REQUIRE_HEADSET and not HeadsetManager.isActive() and not headsetInitialized then
        if now >= nextOpaqueRetryAt then
            nextOpaqueRetryAt = now + OPAQUE_RETRY_INTERVAL_SEC
            if HeadsetManager.init() then
                headsetInitialized = true
                print("Headset initialized on retry.")
            else
                print("Headset still unavailable; retrying...")
            end
        end
    end
    
    if not opaqueChannelInitialized and now >= nextOpaqueRetryAt then
        nextOpaqueRetryAt = now + OPAQUE_RETRY_INTERVAL_SEC
        if CloudXRManager.initOpaqueDataChannel() then
            opaqueChannelInitialized = true
            print("Opaque Data Channel initialized on retry.")
        end
    end

    -- Update CloudXR opaque data channels
    -- This processes any incoming data from the headset and sends outgoing data
    if CloudXRManager and opaqueChannelInitialized then
        CloudXRManager.update()
    end

    -- Update camera hook and queue outbound metadata to client.
    CameraHook.update(dt)
    local outbound = CameraHook.popOutboundMessage()
    if outbound and CloudXRManager then
        CloudXRManager.queueOutboundData(outbound)
    end
    
    -- Update audio manager to check for hand gestures
    if REQUIRE_HEADSET and HeadsetManager.isActive() and not audioInitAttempted then
        audioInitAttempted = true
        if not AudioManager.init() then
            print("Failed to initialize Audio Manager")
        end
    end

    if REQUIRE_HEADSET and HeadsetManager.isActive() and AudioManager then
        AudioManager.update()
    end

    if opaqueChannelInitialized and not appReadyLogged then
        appReadyLogged = true
        print("Application initialized successfully")
    end
end
