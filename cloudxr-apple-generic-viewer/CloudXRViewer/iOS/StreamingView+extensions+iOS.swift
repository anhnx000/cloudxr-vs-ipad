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