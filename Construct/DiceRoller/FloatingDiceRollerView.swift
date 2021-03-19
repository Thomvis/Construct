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
    static let alignments: [SwiftUI.Alignment] = [.bottomTrailing, .topLeading, .topTrailing, .bottomLeading]
    static let containerCoordinateSpaceName = "FloatingDiceRollerContainerView"

    static let innerPanelPadding: CGFloat = 12.0
    static let panelToolbarVerticalPadding: CGFloat = 6.0

    let store: Store<FloatingDiceRollerViewState, FloatingDiceRollerViewAction>
    @ObservedObject var viewStore: ViewStore<FloatingDiceRollerViewState, FloatingDiceRollerViewAction>

    @State var alignment: SwiftUI.Alignment = .bottomTrailing

    @State var dragOffset: CGSize = .zero

    init(store: Store<FloatingDiceRollerViewState, FloatingDiceRollerViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.hidden == $1.hidden })
    }

    var body: some View {
        GeometryReader { containerProxy in
            ZStack(alignment: alignment) {
                Color.clear // to make the ZStack fill all available space

                VStack {
                    HStack {
                        Spacer()

                        Button(action: {
                            withAnimation {
                                viewStore.send(.hide)
                            }
                        }) {
                            Image(systemName: "pip.remove")
                        }
                    }
                    .background(Color(UIColor.systemGray6).padding(EdgeInsets(
                                                                    top: -Self.panelToolbarVerticalPadding,
                                                                    leading: -Self.innerPanelPadding,
                                                                    bottom: -Self.panelToolbarVerticalPadding,
                                                                    trailing: -Self.innerPanelPadding))
                    )
                    .padding([.top, .bottom], Self.panelToolbarVerticalPadding)
                    .padding(.bottom, Self.panelToolbarVerticalPadding)

                    DiceCalculatorView(store: store.scope(state: { $0.diceCalculator }, action: { .diceCalculator($0) }))
                }
                .frame(width: 280)
                .fixedSize()
                .padding([.leading, .trailing, .bottom], Self.innerPanelPadding)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 5)
                .offset(dragOffset)
                .gesture(
                    DragGesture(coordinateSpace: .named(Self.containerCoordinateSpaceName))
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                self.dragOffset = .zero
                                guard let up = self.alignment.unitPoint else { return }
                                self.alignment = targetAlignment(
                                    for: CGPoint(x: containerProxy.size.width * up.x, y: containerProxy.size.height * up.y)
                                        + CGPoint(x: 140, y: 200) // approximate panel size, removes the need for a GeometryReader/anchorPreference
                                        + CGPoint(value.predictedEndTranslation),
                                    in: containerProxy.size
                                )
                            }
                        }
                )
            }
            .coordinateSpace(name: Self.containerCoordinateSpaceName)
            .padding(12)
            .opacity(viewStore.state.hidden ? 0 : 1)
        }
    }

    func targetAlignment(for location: CGPoint, in containerSize: CGSize) -> SwiftUI.Alignment {
        return Self.alignments
            .compactMap { alignment -> (SwiftUI.Alignment, CGFloat)? in
                alignment.unitPoint.map { up in
                    (alignment, CGPoint(x: containerSize.width * up.x, y: containerSize.height * up.y).distance(to: location))
                }
            }
            .sorted { $0.1 < $1.1 }
            .first?.0 ?? .bottomTrailing
    }

}

private extension SwiftUI.Alignment {
    var unitPoint: UnitPoint? {
        switch self {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        default: return nil
        }
    }
}
