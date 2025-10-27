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
    let store: Store<DiceActionFeature.State, DiceActionFeature.Action>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack {

                VStack {
                    ForEachStore(store.scope(state: { $0.action.steps }, action: { .stepAction($0, $1) })) { store in
                        StepView(store: store)
                    }
                }

                HStack {
                    FeedbackButton {
                        viewStore.send(.onFeedbackButtonTap)
                    }

                    Spacer()
                    Button(action: {
                        viewStore.send(.rollAll, animation: .default)
                    }) {
                        Text("Re-roll all")
                    }
                }
            }
            .onAppear {
                if viewStore.action.steps.allSatisfy({ $0.rollValue?.result == nil }) {
                    viewStore.send(.rollAll)
                }
            }
        }
    }

    struct StepView: View {
        let store: Store<DiceAction.Step, DiceActionFeature.StepAction>

        var body: some View {
            WithViewStore(store, observe: \.self) { viewStore in
                VStack(spacing: 8) {
                    HStack {
                        SimpleButton(action: {
                            viewStore.send(.value(.roll(.details(.firstRoll))), animation: .default)
                        }) {
                            VStack(alignment: .leading) {
                                Text(viewStore.state.title)

                                if let subtitle = viewStore.state.subtitle {
                                    Text(subtitle.localizedFirstLetterCapitalized)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(minHeight: 50)
                        }
                        Spacer()

                        IfLetStore(store.scope(state: { $0.rollValue }, action: { .value(.roll($0)) })) { store in
                            RollValueView(step: viewStore.state, store: store)
                        }
                    }

                    if viewStore.state.rollDetails != nil {
                        RollDetailView(step: viewStore.state, store: self.store)
                    }

                    Divider()
                }
            }
        }

        struct RollValueView: View {
            let step: DiceAction.Step
            let store: Store<DiceAction.Step.Value.RollValue, DiceActionFeature.StepAction.ValueAction.RollAction>

            var body: some View {
                WithViewStore(store, observe: \.self) { viewStore in
                    HStack {
                        if viewStore.state.isToHit {
                            Menu(content: {
                                Button(action: {
                                    viewStore.send(.type(.advantage), animation: .default)
                                }) {
                                    Label("Advantage", systemImage: "arrow.up.circle")
                                }

                                Button(action: {
                                    viewStore.send(.type(.normal), animation: .default)
                                }) {
                                    Label("Normal", systemImage: "equal.circle")
                                }

                                Button(action: {
                                    viewStore.send(.type(.disadvantage), animation: .default)
                                }) {
                                    Label("Disadvantage", systemImage: "arrow.down.circle")
                                }
                            }) {
                                Image(systemName: "ellipsis.circle")
                            }
                        }

                        SimpleButton(action: {
                            viewStore.send(.details(viewStore.state.details.toggled(.firstRoll)), animation: .default)
                        }) {
                            rollView(ViewStore(store, observe: { $0.first }), step, viewStore.state, .firstRoll)
                                .opacity(viewStore.state.details == .secondRoll ? 0.33 : 1.0)
                        }

                        IfLetStore(store.scope(state: { $0.second }, action: { $0 })) { store in
                            WithViewStore(store, observe: \.self) { secondViewStore in
                                SimpleButton(action: {
                                    viewStore.send(.details(viewStore.state.details.toggled(.secondRoll)), animation: .default)
                                }) {
                                    rollView(secondViewStore, step, viewStore.state, .secondRoll)
                                        .opacity(viewStore.state.details == .firstRoll ? 0.33 : 1.0)
                                }
                            }
                        }
                    }
                }
            }

            private func rollView(_ viewStore: ViewStore<AnimatedRoll.State, DiceActionFeature.StepAction.ValueAction.RollAction>, _ step: DiceAction.Step, _ rollValue: DiceAction.Step.Value.RollValue, _ roll: DiceAction.Step.Value.RollValue.Details) -> some View {
                AnimatedRollView(roll: viewStore.binding(send: { _ in fatalError() })) { res, final in
                    Text("\(res?.total ?? 0)")
                        .underline(res != nil && res?.total == res?.unroll.maximum)
                        .italic(res != nil && res?.total == res?.unroll.minimum)
                        .foregroundColor(rollValue.emphasis(for: roll).map { emphasisColor(for: $0) })
                        .opacity(final ? 1 : 0.66)
                        .opacity(rollValue.emphasis(for: roll.other) == nil ? 1 : 0.33)
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
            let store: Store<DiceAction.Step, DiceActionFeature.StepAction>

            var body: some View {
                WithViewStore(store, observe: \.self) { viewStore in
                    IfLetStore(self.store.scope(state: { $0.rollDetails?.result(includingIntermediary: true) }, action: { .rollDetails($0) })) { store in
                        ResultDetailView(store: store)
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
}

#if DEBUG
struct DiceActionViewDebugHost: View {
    var env: ActionResolutionEnvironment

    var body: some View {
        DiceActionView(store: Store(
            initialState: DiceActionFeature.State(
                creatureName: "",
                action: DiceAction(
                    title: "Scimitar",
                    parsedAction: CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage.")!
                )!
            )
        ) {
            DiceActionFeature(environment: env)
        })
    }
}
#endif
