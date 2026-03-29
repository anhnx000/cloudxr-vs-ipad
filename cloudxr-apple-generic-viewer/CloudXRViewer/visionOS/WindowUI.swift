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
import RealityKit

struct GenericWindowUI: View {
    enum Section {
        case hud
        case launch
        case actions

        var title: String {
            switch self {
            case .hud:
                "HUD"
            case .launch:
                "Config Screen"
            case .actions:
                "Actions"
            }
        }
    }

    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    /// Current section being displayed
    @State var section = Section.launch

    // States for the selected opaque data channel.
    @State var currentChannelSelection: ChannelInfo?
    @State var currentChannel: MessageChannel?

    @Binding var application: Application

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
#endif

        VStack {
            titleBar
                .padding(.all)

            // decide which panel to show in this window
            switch section {
            case .hud:
                if let session = appModel.session {
                    ScrollView {
                        HUDView(session: session, hudConfig: HUDConfig())
                    }
                }
            case .launch:
                SessionConfigView(application: $application) {}
            case .actions:
                ServerActionsView(
                    currentChannelSelection: $currentChannelSelection,
                    currentChannel: $currentChannel
                )
            }
        }
        .ornament(visibility: .visible, attachmentAnchor: .scene(.init(x: 0.5, y: 0.92))) {
            // view selection "tabs" along the bottom of the window
            HStack {
                Button("HUD") {
                    section = .hud
                }
                .selectedStyle(isSelected: section == .hud)
                Button("Config Screen") {
                    section = .launch
                }
                .selectedStyle(isSelected: section == .launch)
                Button("Server Actions") {
                    section = .actions
                }
                .selectedStyle(isSelected: section == .actions)
            }
            .ornamentStyle
        }
        // align all the useful information to the top of the window
        Spacer()
    }

    /// The titlebar at the top of the panel showing the panel name and controls at left and right
    var titleBar: some View {
        HStack {
            Spacer()

            VStack{
                // Title
                Text(section.title)
                    .font(UIConstants.titleFont)

                Button(appModel.ratingText) {
                    appModel.isRatingViewPresented = true
                }
                .disabled(appModel.disableFeedback)
                .sheet(isPresented: Binding(get: { appModel.isRatingViewPresented }, set: { _ in } )) {
                    StarRatingView()
                }
            }

            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()

    return GenericWindowUI(application: $appModel.application)
        .environment(appModel)
}