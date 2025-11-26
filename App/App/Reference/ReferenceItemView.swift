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
        NavigationStack {
            ZStack {
                if let compendiumStore = store.scope(state: \.content.compendiumState?.compendium, action: \.contentCompendium.compendium) {
                    CompendiumIndexView(store: compendiumStore)
                }

                if let combatantDetailStore = store.scope(state: \.content.combatantDetailState, action: \.contentCombatantDetail) {
                    CombatantDetailView(store: combatantDetailStore)
                }

                if let addCombatantStore = store.scope(state: \.content.addCombatantState, action: \.contentAddCombatant) {
                    AddCombatantReferenceItemView(store: addCombatantStore)
                }

                if let compendiumItemStore = store.scope(state: \.content.compendiumItemState, action: \.contentCompendiumItem) {
                    CompendiumEntryDetailView(store: compendiumItemStore)
                }

                if let safariStore = store.scope(state: \.content.safariState, action: \.contentSafari) {
                    SafariView(store: safariStore)
                        .navigationBarHidden(true)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        // Work-around for a blank tab when the iPad app is running on a mac
        // Usually, macOS would convert the attempt to show a SFSafariViewController
        // to a link open in Safari. This works on the Settings/About screen, but not here
        // for some reason. So we do it manually.
        .onAppear {
            if let url = store.content.safariState?.url, ProcessInfo.processInfo.isiOSAppOnMac {
                self.openURL(url)
                store.send(.close)
            }
        }
    }

    struct CombatantDetailView: View {
        let store: Store<ReferenceItem.State.Content.CombatantDetail, ReferenceItem.Action.CombatantDetail>

        var body: some View {
            Construct.CombatantDetailView(store: store.scope(state: \.detailState, action: \.detail))
                .id(store.selectedCombatantId)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: {
                            store.send(.previousCombatantTapped)
                        }) {
                            Image(systemName: "chevron.left")
                        }

                        Button(action: {
                            store.send(.togglePinToTurnTapped)
                        }) {
                            Image(systemName: store.pinToTurn ? "pin.fill" : "pin")
                        }
                        .disabled(store.runningEncounter == nil)

                        Button(action: {
                            store.send(.nextCombatantTapped)
                        }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
        }
    }
}
