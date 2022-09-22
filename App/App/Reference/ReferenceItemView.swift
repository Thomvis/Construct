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
    @SwiftUI.Environment(\.openURL) private var openURL

    let store: Store<ReferenceItemViewState, ReferenceItemViewAction>

    var body: some View {
        // TODO: not all content should be presented in a NavigationView
        WithViewStore(store, removeDuplicates: { $0.content.typeHash == $1.content.typeHash }) { viewStore in
            NavigationView {
                ZStack {
                    IfLetStore(store.scope(state: { $0.content.compendiumState?.compendium }, action: { .contentCompendium(.compendium($0)) })) { store in
                        CompendiumIndexView(store: store)
                    }

                    IfLetStore(store.scope(state: { $0.content.combatantDetailState }, action: { .contentCombatantDetail($0) }), then: CombatantDetailView.init)

                    IfLetStore(store.scope(state: { $0.content.addCombatantState }, action: { .contentAddCombatant($0) }), then: AddCombatantReferenceItemView.init)

                    IfLetStore(store.scope(state: { $0.content.compendiumItemState }, action: { .contentCompendiumItem($0) }), then: CompendiumItemDetailView.init)

                    IfLetStore(store.scope(state: { $0.content.safariState}, action: { _ in .contentSafari })) { (store: Store<SafariViewState, Void>) in
                        SafariView(store: store)
                            .navigationBarHidden(true)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            // Work-around for a blank tab when the iPad app is running on a mac
            // Usually, macOS would convert the attempt to show a SFSafariViewController
            // to a link open in Safari. This works on the Settings/About screen, but not here
            // for some reason. So we do it manually.
            .onAppear {
                if let url = viewStore.state.content.safariState?.url, ProcessInfo.processInfo.isiOSAppOnMac {
                    self.openURL(url)
                    viewStore.send(.close)
                }
            }
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
