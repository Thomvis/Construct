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
import Helpers
import DiceRollerFeature

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
        self.viewStore = ViewStore(store, removeDuplicates: {
            ($0.hidden, $0.canCollapse, $0.content, $0.diceLog.entries.isEmpty) ==
            ($1.hidden, $1.canCollapse, $1.content, $1.diceLog.entries.isEmpty)
        })
    }

    var body: some View {
        GeometryReader { containerProxy in
            ZStack(alignment: alignment) {
                Color.clear // to make the ZStack fill all available space

                if viewStore.state.hidden {
                    Button(action: {
                        alignment = .bottomTrailing
                        viewStore.send(.show, animation: .default)
                    }) {
                        Image("tabbar_d20")
                            .padding(18)
                            .background(
                                Circle().foregroundColor(Color(UIColor.secondarySystemBackground))
                                    .shadow(color: Color.black.opacity(0.33), radius: 5)
                            )
                            .padding(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .transition(.identity) // its (dis)appearance is overshadowed by the dice popover
                }

                panel(containerProxy)
                    .opacity(viewStore.state.hidden ? 0 : 1)
            }
            .coordinateSpace(name: Self.containerCoordinateSpaceName)
            .padding(EdgeInsets(top: 8, leading: 12, bottom: 50, trailing: 12))
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private func panel(_ containerProxy: GeometryProxy) -> some View {
        let dragGesture = DragGesture(coordinateSpace: .named(Self.containerCoordinateSpaceName))
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

        return VStack {
            HStack {
                Button(action: {
                    if viewStore.state.content == .log {
                        viewStore.send(.content(.calculator), animation: .default)
                    } else {
                        viewStore.send(.content(.log), animation: .default)
                    }
                }) {
                    if viewStore.state.content == .log {
                        Image("tabbar_d20")
                    } else {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                .disabled(viewStore.state.content == .calculator && viewStore.state.diceLog.entries.isEmpty)

                Spacer()

                Button(action: {
                    viewStore.send(.collapse, animation: .default)
                }) {
                    Image(systemName: "rectangle.arrowtriangle.2.inward")
                }
                .disabled(!viewStore.canCollapse)

                Button(action: {
                    viewStore.send(.hide, animation: .default)
                }) {
                    Image(systemName: "pip.remove")
                }
            }
            .background(Color(UIColor.systemGray4).padding(EdgeInsets(
                                                            top: -Self.panelToolbarVerticalPadding,
                                                            leading: -Self.innerPanelPadding,
                                                            bottom: -Self.panelToolbarVerticalPadding,
                                                            trailing: -Self.innerPanelPadding))
            )
            .padding([.top, .bottom], Self.panelToolbarVerticalPadding)
            .padding(.bottom, Self.panelToolbarVerticalPadding)

            switch viewStore.state.content {
            case .calculator: DiceCalculatorView(store: store.scope(state: { $0.diceCalculator }, action: { .diceCalculator($0) }))
            case .log:
                WithViewStore(store.scope(state: { $0.diceLog })) { viewStore in
                    DiceLogFeedView(entries: viewStore.state.entries)
                        .frame(height: 300)
                }
            }
        }
        .frame(width: 280)
        .fixedSize()
        .padding([.leading, .trailing, .bottom], Self.innerPanelPadding)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.33), radius: 5)
        .offset(dragOffset)
        .gesture(dragGesture)
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
