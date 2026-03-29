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

import simd
import Spatial
import RealityKit

public extension simd_float3 {
    static var xAxis: simd_float3 { [1, 0, 0] }
    static var yAxis: simd_float3 { [0, 1, 0] }
    static var zAxis: simd_float3 { [0, 0, 1] }
}

public extension simd_float4x4 {
    static var identity: simd_float4x4 { matrix_identity_float4x4 }
    static var zero: simd_float4x4 { simd_float4x4() }

    init(radians: Float, axis: simd_float3) {
        let quat = simd_quatf(angle: radians, axis: axis)
        self.init(quat)
    }

    static func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
        var matrix: simd_float4x4 = .identity
        matrix[3] = [x, y, z, 1.0]
        return matrix
    }
}

public extension simd_quatf {
    static var identity = simd_quatf.init(matrix_float4x4.identity)
}
