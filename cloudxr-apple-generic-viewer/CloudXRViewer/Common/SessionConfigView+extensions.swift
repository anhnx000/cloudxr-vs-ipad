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
import OSLog

enum AuthMethod: String, CaseIterable {
    case starfleet = "Geforce NOW login"
    case guest = "Guest Mode"
}

enum Zone: String, CaseIterable {
    case auto = "Auto"
    case us_east = "US East"
    case us_northwest = "US Northwest"
    case us_west = "US West"
    case eu_north = "EU North"
    case ipAddress = "Manual IP address"

    var id: String? {
        switch self {
        case .auto:
            nil // automatic
        case .us_east:
           "np-atl-03" // "us-east"
        case .us_northwest:
           "np-pdx-01" // "us-northwest"
        case .us_west:
            "np-sjc6-04" // "us-west"
        case .eu_north:
            "np-sth-04" // "eu-north"
        default:
            nil
        }
    }
}

enum AppID: UInt, CaseIterable {
    // Add CMS IDs here
    case unknown

    var rawValue: UInt {
        switch self {
        case .unknown:
            return 000_000_000
        }
    }
}

enum Application: String, CaseIterable {


    case generic_viewer = "Generic Viewer"

    var appID: AppID {
        switch self {
            // Add mapping from Applications to CMS IDs here
        default:
            .unknown
        }
    }

    var isConfigurator: Bool {
        switch self {
        case .generic_viewer:
            false

        }
    }
}

extension SessionConfigView {

    var stateDescription: String {
        appModel.session?.state.description ?? ""
    }

    var buttonLabel: String {
        switch appModel.session?.state {
        case .connected: "Disconnect"
        case .paused, .pausing: "Resume"
        default: "Connect"
        }
    }

    var usingGuestMode: Bool {
        authMethod == .guest && zone != .ipAddress
    }

    var connectButtonDisabled: Bool {
        switch appModel.session?.state {
        case .connecting, .authenticating, .authenticated, .disconnecting, .resuming, .pausing:
            true
        default:
            false
        }
    }
}