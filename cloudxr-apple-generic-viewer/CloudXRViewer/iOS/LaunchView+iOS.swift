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
    @Environment(AppModel.self) var appModel
    @Environment(\.colorScheme) var colorScheme
    

    @Binding var application: Application

    var body: some View {

        if !application.isConfigurator {
            if appModel.showStreamingAppView {
                BasicStreamingView(application: $application)
            } else {
                VStack {
                    Spacer(minLength: 24)
                    SessionConfigView(application: $application) {}
                    Spacer(minLength: 24)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()

    appModel.application = .generic_viewer
    appModel.session = CloudXRSession(config: Config())

    return LaunchView(application: $appModel.application)
        .environment(appModel)
}