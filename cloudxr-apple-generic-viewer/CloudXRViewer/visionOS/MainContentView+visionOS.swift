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
import RealityKit
import CloudXRKit

struct MainContentView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) var scenePhase
    @Environment(AppModel.self) var appModel


    @Binding var application: Application
    @State var showLiveStats: Bool = false

    private func networkQualityIndicator(for quality: CloudXRKit.Session.SessionQuality?) -> (color: Color, value: Double) {
        switch quality {
        case .excellent:
            return (.green, 1.0)
        case .good:
            return (.green, 0.75)
        case .degraded:
            return (.yellow, 0.5)
        case .unsustainable:
            return (.red, 0.25)
        default:
            return (.gray, 0.0)
        }
    }

    func makeNetworkIcon() -> some View {
        let indicator = networkQualityIndicator(for: appModel.session?.sessionQuality)

        return Image(systemName: "cellularbars", variableValue: indicator.value)
            .foregroundStyle(indicator.color)
            .padding(12)
    }

    var body: some View {
        VStack {

            if !application.isConfigurator {
                GenericWindowUI(application: $application)
            }
        }
        .ornament(
            attachmentAnchor: .scene(.init(x: 0.98, y: -0.02)),
            contentAlignment: .bottomTrailing
        ) {
            Button {
                showLiveStats.toggle()
            } label: {
                makeNetworkIcon()
            }
        }
        .sheet(isPresented: $showLiveStats) {
            NetworkStatsView(
                session: appModel.session,
                onClose: { showLiveStats = false }
            )
        }
    }
}

struct NetworkStatsView: View {
    let session: Session?
    let onClose: () -> Void

    private var stats: (latency: String, jitter: String, bandwidth: String) {
        let latencyText = session?.liveNetworkStats.latencyMilliseconds.map(String.init) ?? "N/A"
        let jitterText = session?.liveNetworkStats.jitterMilliseconds.map(String.init) ?? "N/A"
        let bandwidthText = session?.liveNetworkStats.bandwidthMbps.map(String.init) ?? "N/A"
        return (latencyText, jitterText, bandwidthText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Network Statistics")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .padding(16)
                }
                .buttonStyle(.borderedProminent)
                .contentShape(Circle())
                .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)

            Divider()
                .padding(.horizontal, 8) // Inset divider slightly

            // Content
            VStack(alignment: .leading, spacing: 18) {
                StatRow(title: "Latency", value: stats.latency, unit: "ms")
                StatRow(title: "Jitter", value: stats.jitter, unit: "ms")
                StatRow(title: "Bandwidth", value: stats.bandwidth, unit: "Mbps")
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .padding(.bottom, 4) // Extra bottom padding for rounded corners
        }
        .frame(minWidth: 320, maxWidth: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .presentationDetents([.height(220)]) // Slightly taller for better proportions
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.clear) // Let the background show through
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4) // Small internal padding for better touch targets
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()

    return MainContentView(application: $appModel.application)
        .environment(appModel)
}
