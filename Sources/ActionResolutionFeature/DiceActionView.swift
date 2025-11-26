//
//  DiceActionView.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews
import DiceRollerFeature
import GameModels

struct DiceActionView: View {
    let store: StoreOf<DiceActionFeature>

    var body: some View {
        VStack {
            ForEach(store.scope(state: \.action.steps, action: \.steps)) { stepStore in
                StepView(store: stepStore)
            }

            HStack {
                FeedbackButton {
                    store.send(.onFeedbackButtonTap)
                }

                Spacer()
                Button(action: {
                    store.send(.rollAll, animation: .default)
                }) {
                    Text("Re-roll all")
                }
            }
        }
        .onAppear {
            if store.action.steps.allSatisfy({ $0.rollValue?.result == nil }) {
                store.send(.rollAll)
            }
        }
    }

    struct StepView: View {
        let store: StoreOf<DiceActionFeature.Step>

        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    SimpleButton(action: {
                        store.send(.value(.roll(.details(.firstRoll))), animation: .default)
                    }) {
                        VStack(alignment: .leading) {
                            Text(store.title)

                            if let subtitle = store.subtitle {
                                Text(subtitle.localizedFirstLetterCapitalized)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(minHeight: 50)
                    }
                    Spacer()

                    if let rollValueStore = store.scope(state: \.rollValue, action: \.value.roll) {
                        RollValueView(step: store.state, store: rollValueStore)
                    }
                }

                if store.rollDetails != nil {
                    RollDetailView(step: store.state, store: store)
                }

                Divider()
            }
        }

        struct RollValueView: View {
            let step: DiceAction.Step
            let store: Store<DiceAction.Step.Value.RollValue, DiceActionFeature.StepAction.ValueAction.RollAction>

            var body: some View {
                HStack {
                    if store.isToHit {
                        Menu(content: {
                            Button(action: {
                                store.send(.type(.advantage), animation: .default)
                            }) {
                                Label("Advantage", systemImage: "arrow.up.circle")
                            }

                            Button(action: {
                                store.send(.type(.normal), animation: .default)
                            }) {
                                Label("Normal", systemImage: "equal.circle")
                            }

                            Button(action: {
                                store.send(.type(.disadvantage), animation: .default)
                            }) {
                                Label("Disadvantage", systemImage: "arrow.down.circle")
                            }
                        }) {
                            Image(systemName: "ellipsis.circle")
                        }
                    }

                    let firstStore = store.scope(state: \.first, action: \.first)
                    SimpleButton(action: {
                        store.send(.details(store.details.toggled(.firstRoll)), animation: .default)
                    }) {
                        rollView(firstStore.state, step, store.state, .firstRoll)
                            .opacity(store.details == .secondRoll ? 0.33 : 1.0)
                    }

                    if let secondStore = store.scope(state: \.second, action: \.second) {
                        SimpleButton(action: {
                            store.send(.details(store.details.toggled(.secondRoll)), animation: .default)
                        }) {
                            rollView(secondStore.state, step, store.state, .secondRoll)
                                .opacity(store.details == .firstRoll ? 0.33 : 1.0)
                        }
                    }
                }
            }

            private func rollView(_ roll: AnimatedRoll.State, _ step: DiceAction.Step, _ rollValue: DiceAction.Step.Value.RollValue, _ rollDetails: DiceAction.Step.Value.RollValue.Details) -> some View {
                let res = roll.effectiveResult
                let final = roll.isFinal
                return Text("\(res?.total ?? 0)")
                    .underline(res != nil && res?.total == res?.unroll.maximum)
                    .italic(res != nil && res?.total == res?.unroll.minimum)
                    .foregroundColor(rollValue.emphasis(for: rollDetails).map { emphasisColor(for: $0) })
                    .opacity(final ? 1 : 0.66)
                    .opacity(rollValue.emphasis(for: rollDetails.other) == nil ? 1 : 0.33)
                    .font(.headline)
                    .padding(6)
                    .frame(minWidth: 50, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(style: StrokeStyle(lineWidth: 4))
                            .foregroundColor(Color(UIColor.systemGray5))
                    )
                    .animation(nil, value: res)
            }

            private func emphasisColor(for rollType: DiceAction.Step.Value.RollValue.RollType) -> Color {
                switch rollType {
                case .advantage: return Color(UIColor.systemGreen)
                case .disadvantage: return Color(UIColor.systemRed)
                case .normal: return Color(UIColor.label)
                }
            }
        }

        struct RollDetailView: View {
            let step: DiceAction.Step
            let store: StoreOf<DiceActionFeature.Step>

            var body: some View {
                if let result = store.rollDetails?.result(includingIntermediary: true) {
                    ResultDetailView(result: result) { idx in
                        store.send(.rollDetails(.onResultDieTap(idx)), animation: .spring())
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(UIColor.systemGray6).cornerRadius(4)
                    )
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    DiceActionView(store: Store(
        initialState: DiceActionFeature.State(
            creatureName: "",
            action: DiceAction(
                title: "Scimitar",
                parsedAction: CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage.")!
            )!
        )
    ) {
        DiceActionFeature()
    })
}
#endif
