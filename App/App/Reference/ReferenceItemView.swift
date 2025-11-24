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

    let store: StoreOf<ReferenceItem>

    var body: some View {
        // TODO: not all content should be presented in a NavigationView
        WithViewStore(store, observe: \.content.typeHash) { _ in
            NavigationStack {
                ZStack {
                    IfLetStore(store.scope(state: \.content.compendiumState?.compendium, action: \.contentCompendium.compendium)) { store in
                        CompendiumIndexView(store: store)
                    }

                    IfLetStore(store.scope(state: \.content.combatantDetailState, action: \.contentCombatantDetail), then: CombatantDetailView.init)

                    IfLetStore(store.scope(state: \.content.addCombatantState, action: \.contentAddCombatant), then: AddCombatantReferenceItemView.init)

                    IfLetStore(store.scope(state: \.content.compendiumItemState, action: \.contentCompendiumItem), then: CompendiumEntryDetailView.init)

                    IfLetStore(store.scope(state: \.content.safariState, action: \.contentSafari)) { store in
                        SafariView(store: store)
                            .navigationBarHidden(true)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        // Work-around for a blank tab when the iPad app is running on a mac
        // Usually, macOS would convert the attempt to show a SFSafariViewController
        // to a link open in Safari. This works on the Settings/About screen, but not here
        // for some reason. So we do it manually.
        .onAppear {
            if let url = store.withState({ $0.content.safariState?.url }), ProcessInfo.processInfo.isiOSAppOnMac {
                self.openURL(url)
                store.send(.close)
            }
        }
    }

    struct CombatantDetailView: View {
        let store: Store<ReferenceItem.State.Content.CombatantDetail, ReferenceItem.Action.CombatantDetail>

        var body: some View {
            WithViewStore(store, observe: \.self) { viewStore in
                Construct.CombatantDetailView(store: store.scope(state: \.detailState, action: \.detail))
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
