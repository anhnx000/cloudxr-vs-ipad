-- SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
-- SPDX-License-Identifier: MIT

-- CloudXR Manager Module
-- This module handles all CloudXR-related functionality including:
-- - Loading the CloudXR plugin
-- - Starting/stopping the CloudXR runtime service
-- - Managing opaque data channels for custom communication
-- - Processing data received from the headset

local CloudXRManager = {}

-- Global variables to store the CloudXR plugin and received data
local nv_cxr = nil              -- Reference to the loaded CloudXR plugin
local lastReceivedData = nil    -- Cache of the most recent data received from headset
local queuedOutboundData = nil  -- Optional app-originated outbound payload

-- Recorder: captures frames directly from the LOVR render loop via named pipe.
-- No X11 display required.
local Recorder = nil
local recorderAvailable = false
do
    local ok, mod = pcall(require, 'recorder')
    if ok then
        Recorder = mod
        recorderAvailable = true
        print("Recorder module loaded (LOVR frame capture mode)")
    else
        print("Recorder module not available, falling back to record.sh: " .. tostring(mod))
    end
end

-- Initialize the CloudXR plugin by loading the nvidia.dll/nvidia.so library
-- This loads the CloudXR plugin and makes its functions available
function CloudXRManager.init()
    print("Loading NVIDIA CloudXR Runtime plugin...")
    
    -- Use pcall to safely load the plugin (prevents crashes if plugin is missing)
    -- The 'nvidia' module is the CloudXR plugin built into LÖVR
    local success, plugin = pcall(require, 'nvidia')
    if not success then
        print("Failed to load NVIDIA CloudXR plugin:", plugin)
        return false
    end
    
    -- Store reference to the plugin for later use
    nv_cxr = plugin
    print("NVIDIA CloudXR plugin loaded successfully")
    return true
end

-- Initialize and start the CloudXR runtime service
-- This must be called BEFORE OpenXR initialization
function CloudXRManager.initRuntime(args)
    if not nv_cxr then
        print("NVIDIA CloudXR plugin not loaded")
        return false
    end

    -- Initialize the CloudXR plugin (loads the CloudXR library)
    if not nv_cxr.initRuntime() then
        print("Failed to initialize NVIDIA CloudXR plugin")
        nv_cxr.destroyRuntime()
        nv_cxr = nil
        return false
    end
    
    print("NVIDIA CloudXR plugin initialized")
    
    -- Display version information for debugging
    local major, minor, patch = nv_cxr.getRuntimeLibraryApiVersion()
    if major then
        print(string.format("CloudXR Library API Version: %d.%d.%d", major, minor, patch))
    else
        print("Could not get library API version")
    end

    major, minor, patch = nv_cxr.getRuntimeVersion()
    if major then
        print(string.format("CloudXR Runtime Version: %d.%d.%d", major, minor, patch))
    else
        print("Could not get runtime version")
    end

    -- Configure CloudXR runtime properties before starting the service
    -- These settings control how CloudXR behaves and which headset to target

    -- Do not force a headset profile by default.
    -- Forcing "apple-vision-pro" causes config mismatch when the client is iPad.
    -- If needed, the profile can be explicitly provided via env var CXR_DEVICE_PROFILE.
    local forcedProfile = os.getenv("CXR_DEVICE_PROFILE")
    if forcedProfile and forcedProfile ~= "" then
        if not nv_cxr.setRuntimeStringProperty("device-profile", forcedProfile) then
            print("Failed to set device profile:", forcedProfile)
        else
            print("Using forced device profile:", forcedProfile)
        end
    else
        print("No device profile forced; using runtime auto profile selection")
    end

    -- Enable audio streaming to the headset
    if not nv_cxr.setRuntimeBooleanProperty("audio-streaming", true) then
        print("Failed to set enable_audio property")
    end

    -- Early Access: Configure CloudXR runtime properties for Quest 3
    -- https://developer.nvidia.com/cloudxr-sdk-early-access-program
    if args and args.webrtc then
        if not nv_cxr.setRuntimeStringProperty("device-profile", "quest3") then
            print("Failed to set webrtc property")
        end
        
        if not nv_cxr.setRuntimeBooleanProperty("runtime-foveation", true) then
            print("Failed to set runtime-foveation property")
        end
        
        if not nv_cxr.setRuntimeInt64Property("runtime-foveation-unwarped-width", 4096) then
            print("Failed to set runtime-foveation-unwarped-width property")
        end
        
        if not nv_cxr.setRuntimeInt64Property("runtime-foveation-warped-width", 2048) then
            print("Failed to set runtime-foveation-warped-width property")
        end
        
        if not nv_cxr.setRuntimeInt64Property("runtime-foveation-inset", 40) then
            print("Failed to set runtime-foveation-inset property")
        end
    end
    
    -- Start the CloudXR service - this begins the streaming process
    if not nv_cxr.startRuntime() then
        print("Failed to start CloudXR service (this is expected if CloudXR runtime is not available)")
        return false
    end
    
    print("CloudXR service started successfully")
    return true
end

-- Initialize opaque data channels for custom communication with the headset
-- This must be called AFTER OpenXR initialization
function CloudXRManager.initOpaqueDataChannel()
    if not nv_cxr then
        print("NVIDIA CloudXR plugin not loaded")
        return false
    end

    -- Load the OpenXR extension functions for opaque data channels
    if not nv_cxr.initOpaqueDataChannel() then
        print("Failed to load extension functions. Opaque data will not be available.")
        return false
    end

    print("OpenXR extension procedures loaded successfully")

    -- Create a unique identifier for our opaque data channel and store it for reconnects
    -- This UUID identifies this specific communication channel
    -- In a real application, you might want to generate a proper UUID
    -- This example uses "<LOVR Channel>" converted to bytes + padding
    CloudXRManager.opaque_uuid = {60, 76, 79, 86, 82, 32, 67, 104, 97, 110, 110, 101, 108, 62, 0, 0}

    -- Create the opaque data channel with our UUID
    if not nv_cxr.createOpaqueDataChannel(CloudXRManager.opaque_uuid) then
        print("Failed to create opaque data channel")
        return false
    end
    
    print("Opaque data channel created successfully")
    return true
end

-- Update function called every frame to process opaque data
-- This handles incoming data from the headset and sends outgoing data
function CloudXRManager.update()
    if not nv_cxr then
        print("NVIDIA CloudXR plugin not loaded")
        return false
    end

    -- Check if the opaque data channel is connected to a headset
    if nv_cxr.getOpaqueDataChannelState() == nv_cxr.OPAQUE_DATA_CHANNEL_STATUS.CONNECTED then
        -- Send app-originated payload first (if queued by another module).
        if queuedOutboundData then
            local sent = nv_cxr.sendOpaqueDataChannel(queuedOutboundData)
            if not sent then
                print("Failed to send queued outbound data:", queuedOutboundData)
            end
            queuedOutboundData = nil
        end

        -- Try to receive data from the headset
        local data = nv_cxr.receiveOpaqueDataChannel()
        if data then
            print("Received data:", data)
            lastReceivedData = data

            -- Handle record commands sent from the iOS client.
            if data == "cmd:record_start" then
                local active = recorderAvailable and Recorder.isActive() or false
                if not active then
                    if recorderAvailable then
                        local ok, result = Recorder.start()
                        if ok then
                            print("Recording started (LOVR frame capture) → " .. tostring(result))
                            nv_cxr.sendOpaqueDataChannel("status:recording_started")
                        else
                            print("Recorder.start failed: " .. tostring(result))
                            nv_cxr.sendOpaqueDataChannel("status:recording_error")
                        end
                    else
                        print("Recorder not available")
                        nv_cxr.sendOpaqueDataChannel("status:recording_error")
                    end
                else
                    nv_cxr.sendOpaqueDataChannel("status:already_recording")
                end
            elseif data == "cmd:record_stop" then
                local active = recorderAvailable and Recorder.isActive() or false
                if active then
                    local ok, result = Recorder.stop()
                    if ok then
                        print("Recording stopped → " .. tostring(result))
                        nv_cxr.sendOpaqueDataChannel("status:recording_stopped")
                    else
                        print("Recorder.stop failed: " .. tostring(result))
                        nv_cxr.sendOpaqueDataChannel("status:recording_error")
                    end
                else
                    nv_cxr.sendOpaqueDataChannel("status:not_recording")
                end
            else
                -- Echo unknown commands back for debugging.
                local success = nv_cxr.sendOpaqueDataChannel("Echo: " .. data)
                if not success then
                    print("Failed to echo received data:", data)
                end
            end
        end
    elseif nv_cxr.getOpaqueDataChannelState() == nv_cxr.OPAQUE_DATA_CHANNEL_STATUS.DISCONNECTED then
        -- Preserve the UUID before destroying the channel
        local uuid = CloudXRManager.opaque_uuid

        -- Fully destroy the channel to release runtime resources and re-create
        -- the channel with the same UUID
        nv_cxr.destroyOpaqueDataChannel()

        if uuid then
            nv_cxr.createOpaqueDataChannel(uuid)
        end
    end
end

-- Queue one message to be sent to the client on the next connected frame.
function CloudXRManager.queueOutboundData(data)
    if type(data) ~= "string" or data == "" then
        return false
    end
    queuedOutboundData = data
    return true
end

-- Get the most recently received data from the headset
-- This is used by the renderer to display received data
function CloudXRManager.getLastReceivedData()
    return lastReceivedData
end

-- Capture the current frame for recording.
-- Pass a drawCallback function that renders the scene.
-- Called from lovr.draw(pass) in main.lua when recording is active.
function CloudXRManager.captureFrame(drawCallback)
    if recorderAvailable and Recorder.isActive() then
        Recorder.captureFrame(drawCallback)
    end
end

-- Returns true if currently recording.
function CloudXRManager.isRecording()
    return recorderAvailable and Recorder.isActive() or false
end

-- Clean up all CloudXR resources
-- This should be called when the application is shutting down
function CloudXRManager.destroy()
    if nv_cxr then
        print("  Destroying NVIDIA CloudXR plugin...")
        
        -- Clean up opaque data channel resources
        nv_cxr.destroyOpaqueDataChannel()
        
        -- Clean up CloudXR runtime service
        nv_cxr.destroyRuntime()
        
        -- Clear the plugin reference
        nv_cxr = nil
    end
end

return CloudXRManager