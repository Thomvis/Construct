//
//  ReferenceItemView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

private var AssociatedObjectHandle: UInt8 = 0

struct ReferenceItemView: View {

    let store: Store<ReferenceItemViewState, ReferenceItemViewAction>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.content.typeHash == $1.content.typeHash }) { viewStore in
            NavigationView {
                ZStack {
                    IfLetStore(store.scope(state: { $0.content.homeState }, action: { .contentHome($0) }), then: HomeView.init)

                    IfLetStore(store.scope(state: { $0.content.combatantDetailState }, action: { .contentCombatantDetail($0) }), then: CombatantDetailView.init)

                    IfLetStore(store.scope(state: { $0.content.addCombatantState }, action: { .contentAddCombatant($0) }), then: AddCombatantReferenceItemView.init)
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .environment(\.appNavigation, .tab)
        }
    }

    struct CombatantDetailView: View {
        let store: Store<ReferenceItemViewState.Content.CombatantDetail, ReferenceItemViewAction.CombatantDetail>

        var body: some View {
            WithViewStore(store) { viewStore in
                Construct.CombatantDetailView(store: store.scope(state: { $0.detailState }, action: { .detail($0) }))
                    .id(viewStore.state.selectedCombatantId)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button(action: {
                                viewStore.send(.previousCombatantTapped)
                            }) {
                                Image(systemName: "chevron.left")
                            }

                            Button(action: {
                                viewStore.send(.togglePinToTurnTapped)
                            }) {
                                Image(systemName: viewStore.state.pinToTurn ? "pin.fill" : "pin")
                            }
                            .disabled(viewStore.state.runningEncounter == nil)

                            Button(action: {
                                viewStore.send(.nextCombatantTapped)
                            }) {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
            }
        }
    }
}
