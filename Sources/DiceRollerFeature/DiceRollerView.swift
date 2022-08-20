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
import SharedViews
import Dice

public struct DiceRollerView: View {
    public static let outcomePopoverId = UUID()

    var store: Store<DiceRollerViewState, DiceRollerViewAction>
    @ObservedObject var viewStore: ViewStore<DiceRollerViewState, DiceRollerViewAction>
    @State var rot: Double = 0

    let isVisible: Bool

    public init(store: Store<DiceRollerViewState, DiceRollerViewAction>, isVisible: Bool) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.isVisible = isVisible
    }

    public var body: some View {

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

                    DiceLogFeedView(entries: viewStore.state.diceLog.entries)
                        .padding(.trailing, 12)
                        .mask(alignment: .top) {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: 22)

                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(color: .clear, location: .zero),
                                        Gradient.Stop(color: .black, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 100)

                                Color.black

                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(color: .black, location: .zero),
                                        Gradient.Stop(color: .clear, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 20)
                            }
                        }
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

#if DEBUG
struct DiceRollerView_Preview: PreviewProvider {
    static var previews: some View {
        DiceRollerView(
            store: Store(
                initialState: DiceRollerViewState(),
                reducer: DiceRollerViewState.reducer,
                environment: DiceRollerEnvironment(
                    mainQueue: .main,
                    diceLog: DiceLogPublisher(),
                    modifierFormatter: NumberFormatter()
                )
            ),
            isVisible: true
        )
    }
}

let sampleEntries = [
   DiceLogEntry(
       id: UUID().tagged(),
       roll: .custom(1.d(20) + 3),
       results: [
           .init(
               id: UUID().tagged(),
               type: .normal,
               first: (1.d(20)+3).roll,
               second: nil
           )
       ]
   ),
//   DiceLogEntry(
//       id: UUID().tagged(),
//       roll: .custom(1.d(20) + 4),
//       results: [
//           .init(
//               id: UUID().tagged(),
//               type: .advantage,
//               first: (1.d(20)+4).roll,
//               second: (1.d(20)+4).roll
//           ),
//           .init(
//               id: UUID().tagged(),
//               type: .advantage,
//               first: (1.d(20)+4).roll,
//               second: (1.d(20)+4).roll
//           ),
//           .init(
//               id: UUID().tagged(),
//               type: .advantage,
//               first: (1.d(20)+4).roll,
//               second: (1.d(20)+4).roll
//           )
//       ]
//   ),
//   DiceLogEntry(
//       id: UUID().tagged(),
//       roll: .custom(1.d(20) + 5),
//       results: [
//           .init(
//               id: UUID().tagged(),
//               type: .disadvantage,
//               first: (1.d(20)+5).roll,
//               second: (1.d(20)+5).roll
//           ),
//           .init(
//               id: UUID().tagged(),
//               type: .disadvantage,
//               first: (1.d(20)+5).roll,
//               second: (1.d(20)+5).roll
//           )
//       ]
//   ),
//   DiceLogEntry(
//       id: UUID().tagged(),
//       roll: .custom(1.d(20) + 3),
//       results: [
//           .init(
//               id: UUID().tagged(),
//               type: .normal,
//               first: (1.d(20)+3).roll,
//               second: nil
//           )
//       ]
//   ),
//   DiceLogEntry(
//       id: UUID().tagged(),
//       roll: .custom(1.d(20) + 4),
//       results: [
//           .init(
//               id: UUID().tagged(),
//               type: .advantage,
//               first: (1.d(20)+4).roll,
//               second: (1.d(20)+4).roll
//           )
//       ]
//   ),
//   DiceLogEntry(
//       id: UUID().tagged(),
//       roll: .custom(1.d(20) + 5),
//       results: [
//           .init(
//               id: UUID().tagged(),
//               type: .disadvantage,
//               first: (1.d(20)+5).roll,
//               second: (1.d(20)+5).roll
//           )
//       ]
//   )
]
#endif

