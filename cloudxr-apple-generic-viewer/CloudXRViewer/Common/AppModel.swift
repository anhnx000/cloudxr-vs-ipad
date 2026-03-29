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

struct SavedSettings {
    @AppStorage("application") static var application: Application = .generic_viewer
}

/// The data that the app uses to configure its views.
@Observable
public class AppModel {
    public var session: Session?

#if DEBUG
    var disableFeedback = true
#else
    var disableFeedback = false
#endif

    var isRatingViewPresented = false
    var ratingText = "Feedback"
    var showDisconnectionAlert = false

    var showStreamingAppView: Bool {
        guard let session else {
            return false
        }

        if session.state == .connected {
            return true
        }

        return false
    }

    var application = SavedSettings.application {
        didSet {
            SavedSettings.application = application
        }
    }

    #if os(visionOS)
    let windowStateManager = WindowStateManager()
    #endif
}