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

    @Bindable var store: StoreOf<DiceRollerFeature>
    @State var rot: Double = 0

    public init(store: StoreOf<DiceRollerFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
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

                    DiceLogFeedView(
                        entries: store.diceLog.entries,
                        onClearButtonTap: {
                            store.send(.onClearDiceLog, animation: .default)
                        }
                    )
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

            DiceCalculatorView(store: store.scope(state: \.calculatorState, action: \.calculatorState))
                .padding(12)
                .background(Color(UIColor.systemBackground).opacity(0.9))
        }
        .animation(Animation.linear(duration: 90.0).repeatForever(autoreverses: false), value: rot)
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            rot = 1
        }
        .popover(outcomePopover)
    }

    var outcomePopover: Binding<Popover?> {
        return Binding(get: {
            guard store.showOutcome && store.calculatorState.result != nil else { return nil }
            return OutcomePopover(popoverId: Self.outcomePopoverId, store: store.scope(state: \.calculatorState, action: \.calculatorState))
        }, set: {
            if $0 == nil {
                store.send(.hideOutcome)
            }
        })
    }
}

struct OutcomePopover: View, Popover {
    let popoverId: AnyHashable
    @Bindable var store: StoreOf<DiceCalculator>

    var body: some View {
        VStack(alignment: .leading) {
            (Text("Rolling: ") + Text(store.expression.description)).bold()
            Divider()
            OutcomeView(store: store)
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
                initialState: DiceRollerFeature.State()
            ) {
                DiceRollerFeature()
            }
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
