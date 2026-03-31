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

import CloudXRKit
import SwiftUI
import RealityKit
import AVFoundation
import CoreImage
import ImageIO

extension BasicStreamingView {
    private var configButtonImage: String {
        switch selectedSection {
        case .launch:
            "gearshape.fill"
        default:
            "gearshape"
        }
    }

    internal var configButton: some View {
        customButton(
            image: configButtonImage,
            text: "Settings",
            action: {
                if selectedSection == .none {
                    selectedSection = .launch
                } else {
                    selectedSection = .none
                }
            },
            isDisabled: selectedSection != .none && selectedSection != .launch
        )
    }

    private var hudImage: String {
        showHUD ? "chart.bar.fill" : "chart.bar"
    }

    internal var hudButton: some View {
        customButton(
            image: hudImage,
            text: "Statistics",
            action: {
                showHUD.toggle()
            }
        )
    }

    private var actionsImage: String {
        selectedSection == .actions ? "hand.draw.fill" : "hand.draw"
    }

    internal var actionsButton: some View {
        customButton(
            image: actionsImage,
            text: "Actions",
            action: {
                if selectedSection == .none {
                    selectedSection = .actions
                } else {
                    selectedSection = .none
                }
            },
            isDisabled: selectedSection != .none && selectedSection != .actions
        )
    }

    internal var hudView: some View {
        HStack{
            Spacer()
            VStack {
                if let session = appModel.session {
                    HUDView(session: session, hudConfig: HUDConfig())
                        .frame(minWidth: 200, minHeight: 200)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.top, 50)
                }
                Spacer()
            }
            .padding(.top, 20)
        }
        .padding(.trailing, 20)
    }
}

@MainActor
final class IPadCameraStreamController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "ipad.camera.stream.queue")
    private let ciContext = CIContext()
    private var lastFrameTime: TimeInterval = 0
    private var isUploadingFrame = false
    private(set) var isStreaming = false
    private(set) var frameCount = 0
    private var serverHost = ""
    private var frameIntervalSec: TimeInterval = 0.1

    private func cameraStartURL() -> URL? { URL(string: "http://\(serverHost):49080/camera/start") }
    private func cameraFrameURL() -> URL? { URL(string: "http://\(serverHost):49080/camera/frame") }
    private func cameraStopURL() -> URL? { URL(string: "http://\(serverHost):49080/camera/stop") }

    func start(host: String, fps: Int = 10) async throws {
        guard !isStreaming else { return }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "IPadCameraStreamController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Host is empty"])
        }
        serverHost = trimmed
        frameIntervalSec = 1.0 / Double(max(1, min(fps, 20)))
        frameCount = 0
        lastFrameTime = 0
        isUploadingFrame = false

        try await startRemoteCameraSession(fps: fps)
        try configureSession()
        session.startRunning()
        isStreaming = true
    }

    func stop() async {
        guard isStreaming else { return }
        isStreaming = false
        session.stopRunning()
        await stopRemoteCameraSession()
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw NSError(domain: "IPadCameraStreamController", code: 2, userInfo: [NSLocalizedDescriptionKey: "No back camera device"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw NSError(domain: "IPadCameraStreamController", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
        }
        session.addInput(input)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw NSError(domain: "IPadCameraStreamController", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        session.addOutput(videoOutput)
        session.commitConfiguration()
    }

    private func startRemoteCameraSession(fps: Int) async throws {
        guard let url = cameraStartURL() else { throw NSError(domain: "IPadCameraStreamController", code: 5) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        req.httpBody = Data("{\"fps\":\(fps)}".utf8)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "IPadCameraStreamController", code: 6, userInfo: [NSLocalizedDescriptionKey: "camera/start failed"])
        }
    }

    private func stopRemoteCameraSession() async {
        guard let url = cameraStopURL() else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        req.httpBody = Data("{}".utf8)
        _ = try? await URLSession.shared.data(for: req)
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor [weak self] in
            guard let self, self.isStreaming else { return }
            let now = CACurrentMediaTime()
            if now - self.lastFrameTime < self.frameIntervalSec || self.isUploadingFrame {
                return
            }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let qualityKey = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
            guard let jpegData = self.ciContext.jpegRepresentation(
                of: ciImage,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                options: [qualityKey: 0.65]
            ) else { return }
            self.lastFrameTime = now
            self.isUploadingFrame = true
            await self.uploadFrame(jpegData)
            self.isUploadingFrame = false
        }
    }

    private func uploadFrame(_ data: Data) async {
        guard let url = cameraFrameURL(), isStreaming else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.upload(for: req, from: data)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                frameCount += 1
            }
        } catch {
            // Best effort; keep stream alive and continue.
        }
    }
}