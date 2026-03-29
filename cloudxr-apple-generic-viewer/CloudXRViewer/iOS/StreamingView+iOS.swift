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
import ARKit
import Foundation

struct BasicStreamingView : View {
    enum Section {
        case none
        case launch
        case actions
    }

    @Environment(AppModel.self) var appModel

    @Environment(\.colorScheme) var colorScheme

    @State private var sessionEntity = Entity()
    @State var showHUD = false

    @State var selectedSection: Section = .none

    @Binding var application: Application

    @State var currentChannelSelection: ChannelInfo?
    @State var currentChannel: MessageChannel?

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                sessionEntity.name = "Session"
                // The camera that displays virtual RealityKit content and camera passthrough, with tracking capabilities.
                content.camera = .spatialTracking
                if let session = appModel.session {
                    sessionEntity.components[CloudXRSessionComponent.self] = .init(session: session)
                }

                content.add(sessionEntity)
            }
            .edgesIgnoringSafeArea(.all)

            if showHUD {
                hudView
            }

            switch selectedSection {
            case .launch:
                SessionConfigView(application: $application) {}
            case .none:
                EmptyView()
            case .actions:
                ServerActionsView(
                    currentChannelSelection: $currentChannelSelection,
                    currentChannel: $currentChannel
                )
                    .frame(minHeight: 160, maxHeight: 690)
            }

            // Show the overylay UI only when connected.
            if appModel.session?.state == .connected {
                VStack {
                    Spacer()
                    // Button to enable/disable HUD.
                    HStack {
                        actionsButton
                        Spacer()
                        configButton
                        Spacer()
                        hudButton
                    }
                }
                .padding([.leading, .trailing, .bottom], 16)
            } else {
                // Show black/white background instead of passthrough when not connected.
                (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
                // Show the SessionConfigView for user to reconnect.
                SessionConfigView(application: $application) {}
            }
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()

    return BasicStreamingView(application: $appModel.application)
        .environment(appModel)
}