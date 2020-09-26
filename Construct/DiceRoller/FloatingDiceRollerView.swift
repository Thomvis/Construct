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
    static let anchors: [UnitPoint] = [.bottomTrailing, .topLeading, .topTrailing, .bottomLeading]

    let store: Store<DiceCalculatorState, DiceCalculatorAction>

    @State var anchor: UnitPoint = .bottomTrailing
    @State var panelSize: CGSize = .zero

    @State var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { containerProxy in
            DiceCalculatorView(store: store)
                .frame(minWidth: 250)
                .fixedSize()
                .padding(12)
                .background(Color(UIColor.systemBackground).cornerRadius(12).shadow(radius: 5))
                .background(GeometryReader { panelProxy in
                    Color.clear.preference(key: CollectionViewSizeKey<Int>.self, value: [0: panelProxy.size])
                })
                .position(panelPosition(for: anchor, in: containerProxy.size))
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                self.dragOffset = .zero
                                self.anchor = anchorNearest(
                                    to: panelPosition(for: anchor, in: containerProxy.size) + CGPoint(value.predictedEndTranslation),
                                    in: containerProxy.size
                                )
                            }
                        }
                )
        }.onPreferenceChange(CollectionViewSizeKey<Int>.self) {
            self.panelSize = $0[0] ?? .zero
        }
        .padding(12)
    }

    func panelPosition(for anchor: UnitPoint, in containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: (containerSize.width - panelSize.width) * anchor.x + panelSize.width*0.5,
            y: (containerSize.height - panelSize.height) * anchor.y + panelSize.height*0.5
        )
    }

    func anchorNearest(to position: CGPoint, in containerSize: CGSize) -> UnitPoint {
        return Self.anchors
            .map { ($0, panelPosition(for: $0, in: containerSize).distance(to: position)) }
            .sorted { $0.1 < $1.1 }
            .first?.0 ?? .bottomTrailing
    }

}
