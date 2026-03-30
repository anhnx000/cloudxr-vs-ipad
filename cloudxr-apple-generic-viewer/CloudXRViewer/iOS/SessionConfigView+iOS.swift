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
    }

    @ViewBuilder
    var sessionConfigForm: some View {
        Form {
            Section {
                VStack {
                    Picker("Select Zone", selection: $zone) {
                        ForEach (Zone.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .frame(width: 500)
                    .onChange(of: zone) {
                        if zone == .ipAddress {
                            // Dummy call to trigger request local network permissions early
                            NetServiceBrowser().searchForServices(ofType: "_http._tcp.", inDomain: "local.")
                        }
                    }

                    if zone == .ipAddress {
                        HStack {
                            Text("IP Address")
                                // TODO(chaoyehc): Investigate why removing the padding
                                // causes slight misalignment in the text.
                                .padding(.vertical, 7)
                                .frame(alignment: .leading)
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
                        .frame(width: 500)
                    } else {
                        HStack {
                            Picker("Select Authentication Method", selection: $authMethod) {
                                ForEach (AuthMethod.allCases, id: \.self) { authOption in
                                    Text(authOption.rawValue)
                                }
                            }
                            .frame(width: 500)
                        }
                    }

                    HStack {
                        Text("Resolution Preset")
                            .frame(alignment: .leading)
                        Spacer()
                        Picker("", selection: $resolutionPreset) {
                            ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue)
                            }
                        }
                        .disabled(sessionConnected)
                    }
                    .frame(width: 500)

                    if zone != .ipAddress && application.appID == .unknown {
                        HStack {
                            Text("Enter Application ID")
                                .frame(alignment: .leading)
                            Spacer()
                            TextField("", value: $genericAppID, format: .number.grouping(.never))
                                .disableAutocorrection(true)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: 500)
                    }
                }
            }
        }
        .onAppear {
            // iOS direct-to-server flow should default to manual IP mode.
            // This avoids accidental cloud-zone config that can trigger server/client mismatches.
            if zone != .ipAddress {
                zone = .ipAddress
            }
        }
        .padding(.top, 100)
        .frame(minWidth: 600, maxWidth: 600, minHeight: 360, maxHeight: 690)
    }
}