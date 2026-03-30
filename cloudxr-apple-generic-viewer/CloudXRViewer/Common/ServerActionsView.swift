// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is furnished
// to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice (including the next
// paragraph) shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
// OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Copyright (c) 2008-2025 NVIDIA Corporation. All rights reserved.

import SwiftUI
import CloudXRKit
import os.log

struct ServerActionsView: View {
    static var logger = Logger()
    // Messages are sent via MessageChannel of the session in appModel.
    @Environment(AppModel.self) var appModel

    @State var lastMessageSent: String = ""
    @State var lastMessageReceived: String = ""
    @State private var isRecording: Bool = false

    @Binding var currentChannelSelection: ChannelInfo?
    @Binding var currentChannel: MessageChannel?

    // Reader task for the currently selected channel.
    @State private var channelReaderTask: Task<Void, Never>?
    @State private var receivedMessageCount: Int = 0

    func sendMessage(message: String) {
        guard let channelSelection = currentChannelSelection else {
            Self.logger.warning("No channel selected")
            lastMessageSent = "Error - no channel"
            return
        }

        guard let messageData = message.data(using: .utf8) else {
            Self.logger.warning("String message could not be converted to data")
            lastMessageSent = "Error"
            return
        }

        if let channel = currentChannel {
            if channel.sendServerMessage(messageData) {
                lastMessageSent = message
            } else {
                Self.logger.warning("Failed to send message via current channel")
                lastMessageSent = "Error - failed to send"
            }
        } else {
            Self.logger.warning("No current channel available for send")
            lastMessageSent = "Error - no channel"
        }
    }

    var body: some View {
        Form {
            VStack {
                if let session = appModel.session {
                    Picker("Channels", selection: $currentChannelSelection) {
                        ForEach(session.availableMessageChannels, id: \.self) { channelInfo in
                            Text("Channel [\(channelInfo.uuid.map { String($0) }.joined(separator: ","))]").tag(channelInfo as ChannelInfo?)
                        }
                        Text("None").tag(nil as ChannelInfo?)
                    }
                    .pickerStyle(.menu)
                    .id(session.availableMessageChannels)
                    .onChange(of: currentChannelSelection) {
                        currentChannel = nil
                        // Cancel any existing reader task when switching selection.
                        channelReaderTask?.cancel()

                        guard let channelSelection = currentChannelSelection else {
                            return
                        }
                        guard let channel = session.getMessageChannel(channelSelection) else {
                            return
                        }

                        currentChannel = channel
                        // Start a reader task for the selected channel.
                        channelReaderTask = Task {
                            for await message in channel.receivedMessageStream {
                                receivedMessageCount += 1
                                let text = String(decoding: message, as: UTF8.self)
                                lastMessageReceived = "Message \(receivedMessageCount): " + text
                                if text == "status:recording_started" {
                                    isRecording = true
                                } else if text == "status:recording_stopped" {
                                    isRecording = false
                                }
                            }
                        }
                    }
                    .onChange(of: session.availableMessageChannels) {
                        if let channelSelection = currentChannelSelection,
                           !session.availableMessageChannels.contains(channelSelection)
                        {
                            currentChannelSelection = nil
                            // Cancel reader if selection disappears.
                            channelReaderTask?.cancel()
                            channelReaderTask = nil
                        }
                    }

                    if let channel = currentChannel {
                        Text("Status: \(channel.status.rawValue)")
                    } else {
                        Text("Status: N/A")
                    }
                }

                Divider()

                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button("Action 1") {
                            sendMessage(message: "Action 1")
                        }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Action 2") {
                            sendMessage(message: "Action 2")
                        }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }

                    Divider()

                    HStack(spacing: 24) {
                        Spacer()
                        if !isRecording {
                            Button(action: {
                                sendMessage(message: "cmd:record_start")
                                isRecording = true
                            }) {
                                Label("Record", systemImage: "record.circle")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            .disabled(currentChannelSelection == nil)
                        } else {
                            Button(action: {
                                sendMessage(message: "cmd:record_stop")
                                isRecording = false
                            }) {
                                Label("Stop", systemImage: "stop.circle.fill")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.gray)
                                    .cornerRadius(10)
                            }
                            .disabled(currentChannelSelection == nil)
                        }
                        Spacer()
                    }
                    
                    if isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("Recording...")
                                .foregroundColor(.red)
                                .font(.footnote.bold())
                        }
                    }
                }
                Divider()
                VStack {
                    Text("Last message sent: ")
                    Divider()
                    Text(lastMessageSent)
                    Spacer()
                }
                Divider()
                VStack {
                    Text("Last message received:")
                    Divider()
                    Text(lastMessageReceived)
                    Spacer()
                }
            }
        }
        .onAppear {
            if let channel = currentChannel {
                channelReaderTask?.cancel()
                channelReaderTask = Task {
                    for await message in channel.receivedMessageStream {
                        receivedMessageCount += 1
                        let text = String(decoding: message, as: UTF8.self)
                        lastMessageReceived = "Message \(receivedMessageCount): " + text
                        if text == "status:recording_started" {
                            isRecording = true
                        } else if text == "status:recording_stopped" {
                            isRecording = false
                        }
                    }
                }
            }
        }
        .onDisappear {
            channelReaderTask?.cancel()
            channelReaderTask = nil
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    @Previewable @State var selection: ChannelInfo? = nil
    @Previewable @State var channel: MessageChannel? = nil
    ServerActionsView(currentChannelSelection: $selection, currentChannel: $channel)
        .environment(appModel)
}