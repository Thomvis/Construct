//
//  FloatingDiceRollerView.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct FloatingDiceRollerContainerView: View {

    let store: Store<DiceCalculatorState, DiceCalculatorAction>

    @State var anchor: UnitPoint = .bottomTrailing
    @State var panelSize: CGSize = .zero

    var body: some View {
        GeometryReader { containerProxy in
            VStack {
                DiceCalculatorView(store: store)
                Button(action: {
                    withAnimation {
                        self.anchor = [.bottomTrailing, .topLeading, .topTrailing, .bottomLeading].randomElement()!
                    }
                }) { Text("Move") }
            }
                .fixedSize()
                .padding(12)
                .background(Color(UIColor.systemBackground).cornerRadius(12).shadow(radius: 5))
                .background(GeometryReader { panelProxy in
                    Color.clear.preference(key: CollectionViewSizeKey<Int>.self, value: [0: panelProxy.size])
                })
                .position(panelPosition(containerSize: containerProxy.size))
        }.onPreferenceChange(CollectionViewSizeKey<Int>.self) {
            self.panelSize = $0[0] ?? .zero
        }
        .padding(12)
    }

    func panelPosition(containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: (containerSize.width - panelSize.width) * anchor.x + panelSize.width*0.5,
            y: (containerSize.height - panelSize.height) * anchor.y + panelSize.height*0.5
        )
    }

}
