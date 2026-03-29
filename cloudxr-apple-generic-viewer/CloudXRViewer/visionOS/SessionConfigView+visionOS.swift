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
import Network

extension SessionConfigView {
    var body: some View {
        mainView
        .ornament(
            visibility: useSimpleConfigView ? .visible : .hidden,
            attachmentAnchor: .scene(.init(x: 0.98, y: -0.02)),
            contentAlignment: .bottomTrailing
        ) {
            Button {
                useSimpleConfigView.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .padding(12)
            }
        }
    }

    @ViewBuilder
    var sessionConfigForm: some View {
        Form {
            Section {
                Picker("Select Zone", selection: $zone) {
                    ForEach (Zone.allCases, id: \.self) { Text($0.rawValue) }
                }
                .onChange(of: zone) {
                    if zone == .ipAddress {
                        // Dummy call to trigger request local network permissions early
                        NetServiceBrowser().searchForServices(ofType: "_http._tcp.", inDomain: "local.")
                    }
                }

                if zone == .ipAddress {
                    HStack {
                        Text("IP Address")
                        Spacer()
                        TextField("0.0.0.0", text: $hostAddress)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                            .searchDictationBehavior(.inline(activation: .onLook))
                            .onSubmit {
                                // strip whitespace
                                hostAddress = hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                    }
                } else {
                    HStack {
                        Picker("Select Authentication Method", selection: $authMethod) {
                            ForEach (AuthMethod.allCases, id: \.self) { authOption in
                                Text(authOption.rawValue)
                            }
                        }
                    }
                }

                if !application.isConfigurator {
                    Toggle("Enable Hand Tracking", isOn: $enableHandTracking)
                }

                if zone != .ipAddress && application.appID == .unknown {
                    HStack {
                        Text("Enter Application ID")
                        Spacer()
                        TextField("", value: $genericAppID, format: .number.grouping(.never))
                            .disableAutocorrection(true)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Picker("Resolution Preset", selection: $resolutionPreset) {
                        ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue)
                        }
                    }.disabled(sessionConnected)
                }
            }
        }
        .frame(minHeight: 420, maxHeight: 790)
    }
}