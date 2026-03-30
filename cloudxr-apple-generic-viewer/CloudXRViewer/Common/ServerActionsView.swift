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

// Three distinct recording states shown to the user.
private enum RecordingState {
    case idle        // Ready to record
    case pending     // Command sent, waiting for server confirmation
    case recording   // Server confirmed recording is active
}

struct ServerActionsView: View {
    static var logger = Logger()
    @Environment(AppModel.self) var appModel

    @State var lastMessageSent: String = ""
    @State var lastMessageReceived: String = ""
    @State private var recordingState: RecordingState = .idle

    // Pulsing animation for the red dot while recording.
    @State private var dotPulse: Bool = false

    @Binding var currentChannelSelection: ChannelInfo?
    @Binding var currentChannel: MessageChannel?

    @State private var channelReaderTask: Task<Void, Never>?
    @State private var pendingTimeoutTask: Task<Void, Never>?
    @State private var receivedMessageCount: Int = 0

    @discardableResult
    func sendMessage(message: String) -> Bool {
        guard currentChannelSelection != nil else {
            Self.logger.warning("No channel selected")
            lastMessageSent = "Error - no channel"
            return false
        }
        guard let messageData = message.data(using: .utf8) else {
            Self.logger.warning("String message could not be converted to data")
            lastMessageSent = "Error"
            return false
        }
        if let channel = currentChannel {
            guard channel.status == .ready else {
                Self.logger.warning("Channel is not ready: \(channel.status.rawValue)")
                lastMessageSent = "Error - channel not ready (\(channel.status.rawValue))"
                return false
            }
            if channel.sendServerMessage(messageData) {
                lastMessageSent = message
                return true
            } else {
                Self.logger.warning("Failed to send message via current channel")
                lastMessageSent = "Error - failed to send"
                return false
            }
        } else {
            Self.logger.warning("No current channel available for send")
            lastMessageSent = "Error - no channel"
            return false
        }
    }

    private func startPendingTimeout(seconds: UInt64 = 5) {
        pendingTimeoutTask?.cancel()
        pendingTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if recordingState == .pending {
                    recordingState = .idle
                    lastMessageReceived = "Không nhận phản hồi từ server cho lệnh ghi hình."
                }
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        receivedMessageCount += 1
        lastMessageReceived = "Message \(receivedMessageCount): " + text
        switch text {
        case "status:recording_started":
            pendingTimeoutTask?.cancel()
            recordingState = .recording
        case "status:recording_stopped":
            pendingTimeoutTask?.cancel()
            recordingState = .idle
        case "status:already_recording":
            pendingTimeoutTask?.cancel()
            recordingState = .recording
        case "status:not_recording":
            pendingTimeoutTask?.cancel()
            recordingState = .idle
        case "status:recording_error":
            pendingTimeoutTask?.cancel()
            recordingState = .idle
        default:
            break
        }
    }

    private func startReaderTask(for channel: MessageChannel) {
        channelReaderTask?.cancel()
        channelReaderTask = Task {
            for await message in channel.receivedMessageStream {
                let text = String(decoding: message, as: UTF8.self)
                await MainActor.run { handleServerMessage(text) }
            }
        }
    }

    // MARK: - Recording button

    @ViewBuilder
    private var recordingButton: some View {
        switch recordingState {
        case .idle:
            Button(action: {
                if sendMessage(message: "cmd:record_start") {
                    recordingState = .pending
                    startPendingTimeout()
                }
            }) {
                Label("Record", systemImage: "record.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .disabled(currentChannel == nil)

        case .pending:
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(0.85)
                Text("Starting…")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())

        case .recording:
            Button(action: {
                if sendMessage(message: "cmd:record_stop") {
                    recordingState = .pending
                    startPendingTimeout()
                }
            }) {
                Label("Stop Recording", systemImage: "stop.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .clipShape(Capsule())
            }
            .disabled(currentChannel == nil)
        }
    }

    // MARK: - Recording status banner

    @ViewBuilder
    private var recordingStatusBanner: some View {
        if recordingState == .recording {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(dotPulse ? 1.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: dotPulse
                    )
                    .onAppear { dotPulse = true }
                    .onDisappear { dotPulse = false }
                VStack(alignment: .leading, spacing: 2) {
                    Text("REC")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    Text("Saving to: ~/recordings/record_<timestamp>.mp4")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            VStack(spacing: 0) {
                if let session = appModel.session {
                    Picker("Channels", selection: $currentChannelSelection) {
                        ForEach(session.availableMessageChannels, id: \.self) { channelInfo in
                            Text("Channel [\(channelInfo.uuid.map { String($0) }.joined(separator: ","))]")
                                .tag(channelInfo as ChannelInfo?)
                        }
                        Text("None").tag(nil as ChannelInfo?)
                    }
                    .pickerStyle(.menu)
                    .id(session.availableMessageChannels)
                    .onChange(of: currentChannelSelection) {
                        currentChannel = nil
                        channelReaderTask?.cancel()
                        guard let sel = currentChannelSelection,
                              let ch = session.getMessageChannel(sel) else { return }
                        currentChannel = ch
                        startReaderTask(for: ch)
                    }
                    .onChange(of: session.availableMessageChannels) {
                        if let sel = currentChannelSelection,
                           !session.availableMessageChannels.contains(sel) {
                            currentChannelSelection = nil
                            channelReaderTask?.cancel()
                            channelReaderTask = nil
                        }
                    }

                    if let channel = currentChannel {
                        Text("Status: \(channel.status.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Status: N/A")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider().padding(.vertical, 8)

                HStack {
                    Spacer()
                    Button("Action 1") { sendMessage(message: "Action 1") }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Action 2") { sendMessage(message: "Action 2") }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.vertical, 8)

                Divider().padding(.vertical, 8)

                // Record button + status banner
                VStack(spacing: 12) {
                    recordingButton
                    recordingStatusBanner
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last sent:").font(.caption).foregroundColor(.secondary)
                    Text(lastMessageSent).font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last received:").font(.caption).foregroundColor(.secondary)
                    Text(lastMessageReceived).font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            if let channel = currentChannel {
                startReaderTask(for: channel)
            }
        }
        .onDisappear {
            channelReaderTask?.cancel()
            channelReaderTask = nil
            pendingTimeoutTask?.cancel()
            pendingTimeoutTask = nil
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