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

import CloudXRKit
import SwiftUI
import RealityKit

struct GenericImmersiveView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) var appModel

    @State private var sessionEntity = Entity()

    var body: some View {
        RealityView { content in
            sessionEntity.name = "Session"

            if let session = appModel.session {
                sessionEntity.components[CloudXRSessionComponent.self] = .init(session: session)
            }

            content.add(sessionEntity)

            content.add(makeInvisibleGestureWall())
        } update: { content in

        }
    }

    func makeInvisibleGestureWall() -> Entity {
        // Add an invisible plane that covers the viewport, attached to the headset that can accept gestures
        // so as to not get in the way of gestures on UI objects, the plane is 20 meters away.
        let plane = Entity()
        plane.components.set(InputTargetComponent())
        var collision = CollisionComponent(shapes: [.generateBox(width: 40, height: 40, depth: 0.01)])
        collision.mode = .trigger
        plane.components.set(collision)
        plane.position.z = -20
        return plane
    }
}