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
import ARKit

struct StarRatingView: View {

    @State private var selectedReason = FeedbackReason.none
    @State private var rating: Int = 0
    @State private var ratingSelected = false

    @Environment(AppModel.self) var appModel
    var body: some View {
        VStack {
            Text("Rate your experience")
                .font(.title)
                .padding()
            HStack {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundColor(star <= rating ? .yellow : .gray)
                        .onTapGesture {
                            rating = star
                            ratingSelected = true
                            // 5-star rating does not require a reason
                            if rating == 5 {
                                selectedReason = FeedbackReason.none
                            }
                        }
                }
            }
            .font(.largeTitle)
            .padding()

            if ratingSelected && rating < 5 {
                Picker("Select a reason", selection: $selectedReason) {
                    ForEach(FeedbackReason.allCases, id: \.self) {
                        if $0 == .none {
                            Text("Please select a reason")
                        } else {
                            Text($0.rawValue)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
            }

            Button("Send feedback") {
                appModel.disableFeedback = true
                if selectedReason == FeedbackReason.none {
                    appModel.ratingText = "Score: \(rating)"
                } else {
                    appModel.ratingText = "Score: \(rating), Reason: \(selectedReason.rawValue)"
                }
                appModel.isRatingViewPresented = false
                appModel.session?.sendUserFeedback(rating: rating, selectedReason: selectedReason)
            }
            .disabled(rating==0)
            .padding()
        }
    }
}