//
//  FlipTransition.swift
//  Construct
//
//  Created by Thomas Visser on 02/07/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct FlipModifier: ViewModifier {
    let amount: Angle

    func body(content: Content) -> some View {
        content.rotation3DEffect(
            amount,
            axis: (x: 0.0, y: 1.0, z: 0.0),
            perspective: 0.8
        )
        .opacity(amount == .zero ? 1.0 : 0.0)
    }
}

extension AnyTransition {
    public static var flip: Self {
        .asymmetric(
            insertion: .modifier(active: FlipModifier(amount: .degrees(-180)), identity: FlipModifier(amount: .degrees(0))),
            removal: .modifier(active: FlipModifier(amount: .degrees(180)), identity: FlipModifier(amount: .degrees(0)))
        )
    }
}
