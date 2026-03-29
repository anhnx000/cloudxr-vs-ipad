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

struct UIConstants {
    /// general margin
    static let margin: CGFloat = 20

    /// size of image assets (trim is subject to being 2/3 this size)
    static let assetWidth: CGFloat = 277

    /// size of font used in toolbar at the bottom of the view
    static let toolbarFont: Font = .custom("SF Pro", size: 17)
        .leading(.loose)
        .weight(.bold)

    /// size of font used to headline each section of the window
    static let sectionFont: Font = .custom("SF Pro", size: 24)
        .leading(.loose)
        .weight(.bold)

    /// size of font used in the titlebar of the window
    static let titleFont: Font = .custom("SF Pro", size: 29)
        .leading(.loose)
        .weight(.bold)
}