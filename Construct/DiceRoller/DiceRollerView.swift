//
//  DiceRollerView.swift
//  Construct
//
//  Created by Thomas Visser on 31/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct DiceRollerView: View {
    static let outcomePopoverId = UUID()

    var store: Store<DiceRollerViewState, DiceRollerViewAction>
    @ObservedObject var viewStore: ViewStore<DiceRollerViewState, DiceRollerViewAction>
    @State var rot: Double = 0

    let isVisible: Bool

    init(store: Store<DiceRollerViewState, DiceRollerViewAction>, isVisible: Bool) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.isVisible = isVisible
    }

    var body: some View {

        // workaround: giving focus to the search field in the compendium would
        // cause onAppear to be called here, which would start the animation and
        // cause 99% CPU load. isVisible prevents that, but requires additional evaluation
        if self.rot == 0 && isVisible {
            DispatchQueue.main.async {
                if self.rot == 0 && isVisible {
                    withAnimation(Animation.linear(duration: 90.0).repeatForever(autoreverses: false)) {
                        self.rot = 1
                    }
                }
            }
        }

        return VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack {
                    Image("icon")
                        .resizable()
                        .frame(width: proxy.size.width*0.6, height: proxy.size.width*0.6)
                        .blur(radius: 6)
                        .rotationEffect(Angle(degrees: 360.0 * self.rot))
                        .position(x: proxy.size.width*0.2, y: proxy.size.height*0.2)

                    Image("icon")
                        .resizable()
                        .frame(width: proxy.size.width*0.7, height: proxy.size.width*0.7)
                        .blur(radius: 6)
                        .rotationEffect(Angle(degrees: 360.0 * -self.rot))
                        .position(x: proxy.size.width*0.5, y: proxy.size.height*0.7)

                    Image("icon")
                        .resizable()
                        .frame(width: proxy.size.width*0.3, height: proxy.size.width*0.3)
                        .blur(radius: 6)
                        .rotationEffect(Angle(degrees: 360.0 * self.rot))
                        .position(x: proxy.size.width*0.8, y: proxy.size.height*0.4)

                    LinearGradient(gradient: Gradient(colors: [
                        Color(UIColor.systemBackground).opacity(0.1),
                        Color(UIColor.systemBackground).opacity(0.9)
                    ]), startPoint: .top, endPoint: .bottom)
                }
            }

            DiceCalculatorView(store: store.scope(state: { $0.calculatorState }, action: { .calculatorState($0) }))
                .padding(12)
                .background(Color(UIColor.systemBackground).opacity(0.9))
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            if self.rot == 0 && isVisible {
                withAnimation(Animation.linear(duration: 90.0).repeatForever(autoreverses: false)) {
                    self.rot = 1
                }
            }
        }
        .popover(outcomePopover)
    }

    var outcomePopover: Binding<Popover?> {
        return Binding(get: {
            guard self.viewStore.state.showOutcome && self.viewStore.state.calculatorState.result != nil else { return nil }
            return OutcomePopover(popoverId: Self.outcomePopoverId, store: self.store.scope(state: { $0.calculatorState }, action: { .calculatorState($0) }))
        }, set: {
            if $0 == nil {
                self.viewStore.send(.hideOutcome)
            }
        })
    }
}

struct OutcomePopover: View, Popover {
    let popoverId: AnyHashable
    var store: Store<DiceCalculatorState, DiceCalculatorAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                (Text("Rolling: ") + Text(viewStore.state.expression.description)).bold()
                Divider()
                OutcomeView(store: store)
            }
        }
    }

    func makeBody() -> AnyView {
        return eraseToAnyView
    }
}
