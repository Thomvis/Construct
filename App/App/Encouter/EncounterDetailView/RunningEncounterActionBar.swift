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

    @ScaledMetric(relativeTo: .body)
    private var verticalDividerHeight: CGFloat = 30

    @Bindable var store: StoreOf<EncounterDetailFeature>

    var body: some View {
        HStack(spacing: 12) {
            Menu(content: {
                Button(action: {
                    store.send(.runningEncounter(.previousTurn), animation: .default)
                }) {
                    Label("Previous turn", systemImage: "backward.frame")
                }

                Button(action: {
                    guard let running = store.running else { return }
                    store.send(.setSheet(.runningEncounterLog(RunningEncounterLogViewState(encounter: running, context: nil))))
                }) {
                    Label("Show log", systemImage: "doc.plaintext")
                }

                if !store.encounter.initiativeOrder.isEmpty {
                    Button(action: {
                        store.send(.popover(.encounterInitiative))
                    }) {
                        Label("Re-roll initiative…", systemImage: "hare")
                    }
                }

                Button(action: {
                    store.send(.setSheet(.add(EncounterDetailFeature.AddCombatantSheet(state: AddCombatantFeature.State(encounter: store.encounter)))))
                }) {
                    Label("Add combatants", systemImage: "plus")
                }

                Divider()

                FeedbackMenuButton {
                    store.send(.onFeedbackButtonTap)
                }

                Button(action: {
                    store.send(.stop, animation: .default)
                }) {
                    Label("Stop run", systemImage: "stop.fill")
                }
            }) {
                HStack {
                    Image(systemName: "ellipsis.circle.fill")

                    store.running.map { running in
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

            if store.encounter.initiativeOrder.isEmpty {
                Button(action: {
                    store.send(.popover(.encounterInitiative))
                }) {
                    Text("Roll initiative...")
                }
            } else {
                Button(action: {
                    store.send(.runningEncounter(.nextTurn))
                }) {
                    if store.running?.turn == nil {
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
