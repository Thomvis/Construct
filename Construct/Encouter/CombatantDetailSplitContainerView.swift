//
//  CombatantDetailSplitContainerView.swift
//  Construct
//
//  Created by Thomas Visser on 06/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CombatantDetailColumnContainerView: View {

    let store: Store<CombatantDetailColumnContainerViewState, CombatantDetailSplitContainerViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            TabView(selection: viewStore.binding(
                get: {
                    $0.selectedCombatantId
                },
                send: {
                    .selectedCombatantId($0)
                }
            )) {
                ForEachStore(store.scope(state: { $0.combatantDetailStates }, action: { .combatantDetail($0, $1) })) { store in
                    CombatantDetailView(store: store)
                        .tag(ViewStore(store).combatant.id)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .animation(.spring())
            .toolbar {
                // Setting the title like this updates more reliably than navigationTitle
                ToolbarItem(placement: .principal) {
                    Text(viewStore.encounter.combatant(for: viewStore.selectedCombatantId)?.discriminatedName ?? "")
                        .font(.headline)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        viewStore.send(.pinToTurn(viewStore.state.pinToTurn.toggled()))
                    }) {
                        Label(viewStore.state.pinToTurn ? "Unpin from turn" : "Pin to turn", systemImage: viewStore.state.pinToTurn ? "pin.fill" : "pin.slash")
                    }
                    .disabled(viewStore.state.selectedCombatantId != viewStore.state.runningEncounter?.turn?.combatantId)
                }
            }
        }
    }
}
