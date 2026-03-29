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

struct SelectedStyle: ViewModifier {
    var isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected {
            ZStack {
                content
                    .buttonStyle(.borderedProminent)
                    .tint(Color(white: 1.0, opacity: 0.1))
            }
        } else {
            content
        }
    }
}

extension View {
    /// allows adding `.coatSelectedStyle(isSelected: true)` to make the view look "selected" per `COATSelectedStyle`
    func selectedStyle(isSelected: Bool) -> some View {
        modifier(SelectedStyle(isSelected: isSelected))
    }
}

struct CustomButtonStyle: ButtonStyle {
    let faint = Color(red: 1, green: 1, blue: 1, opacity: 0.05)
    var isDisabled = false
    func makeBody(configuration: Self.Configuration) -> some View {
        if isDisabled {
            configuration.label
                .background(.clear)
        } else {
            configuration.label
                .background(configuration.isPressed ? faint : .clear)
                .hoverEffect(.lift)
        }
    }
}

func customButton(image: String, text: String, action: @escaping () -> Void, isDisabled: Bool = false) -> some View {
    Button(
        action: action,
        label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 170, height: 60)
                HStack {
                    Image(systemName: image)
                        .font(.largeTitle)
                        .foregroundColor(.white)

                    Text(text)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.leading, 20)
            }
        }
    )
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.5 : 1)
}