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

struct LaunchView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) var scenePhase
    @Environment(AppModel.self) var appModel


    @Binding var application: Application

    func showImmersiveSpace() {
        Task {
            await openImmersiveSpace(id: immersiveTitle)
            if !ViewerApp.persistLaunchWindow {
                dismissWindow(id: launchTitle)
            }
        }
    }

    var body: some View {

        if !application.isConfigurator {
                // Just show the launch view while streaming.
            VStack {
                Spacer(minLength: 24)
                SessionConfigView(application: $application) {
                    showImmersiveSpace()
                }
                Spacer(minLength: 24)
            }
            .glassBackgroundEffect()
            .onChange(of: scenePhase) {
                appModel.windowStateManager.windowOnScenePhaseChange(scenePhase: scenePhase)
            }
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()

    return LaunchView(application: $appModel.application)
        .environment(appModel)
}
