//
//  RunningEncounterActionBar.swift
//  Construct
//
//  Created by Thomas Visser on 04/12/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct RunningEncounterActionBar: View {
    @EnvironmentObject var environment: Environment

    @ScaledMetric(relativeTo: .body)
    private var verticalDividerHeight: CGFloat = 30

    @ObservedObject var viewStore: ViewStore<EncounterDetailViewState, EncounterDetailViewState.Action>

    var body: some View {
        HStack(spacing: 12) {
            Menu(content: {
                Button(action: {
                    viewStore.send(.runningEncounter(.previousTurn), animation: .default)
                }) {
                    Label("Previous turn", systemImage: "backward.frame")
                }

                Button(action: {
                    viewStore.send(.sheet(.runningEncounterLog(RunningEncounterLogViewState(encounter: viewStore.state.running!, context: nil))))
                }) {
                    Label("Show log", systemImage: "doc.plaintext")
                }

                if !viewStore.state.encounter.initiativeOrder.isEmpty {
                    Button(action: {
                        viewStore.send(.popover(.encounterInitiative))
                    }) {
                        Label("Re-roll initiative…", systemImage: "hare")
                    }
                }

                Button(action: {
                    viewStore.send(.sheet(.add(AddCombatantSheet(state: AddCombatantState(encounter: viewStore.state.encounter)))))
                }) {
                    Label("Add combatants", systemImage: "plus")
                }

                Divider()

                FeedbackMenuButton {
                    viewStore.send(.onFeedbackButtonTap)
                }

                Button(action: {
                    viewStore.send(.stop, animation: .default)
                }) {
                    Label("Stop run", systemImage: "stop.fill")
                }
            }) {
                HStack {
                    Image(systemName: "ellipsis.circle.fill")

                    viewStore.state.running.map { running in
                        VStack(alignment: .leading) {
                            running.currentTurnCombatant.map { combatant in
                                Text("\(combatant.discriminatedName)'s turn")
                            }
                            running.turn.map { turn in
                                Text("Round \(turn.round)").font(.footnote)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
            }

            Spacer()

            Color.white.frame(width: 1, height: verticalDividerHeight)

            if viewStore.state.encounter.initiativeOrder.isEmpty {
                Button(action: {
                    self.viewStore.send(.popover(.encounterInitiative))
                }) {
                    Text("Roll initiative...")
                }
            } else {
                Button(action: {
                    self.viewStore.send(.runningEncounter(.nextTurn))
                }) {
                    if viewStore.state.running?.turn == nil {
                        Text("Start")
                    } else {
                        Text("Next turn")
                    }
                }
            }
        }
        .foregroundColor(Color.white)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(Color(UIColor.systemBlue))
        .cornerRadius(8)
        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
    }
}
