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
                switch store.state.content {
                case .compendium:
                    if let store = store.scope(state: \.content[case: \.compendium]?.compendium, action: \.contentCompendium.compendium) {
                        CompendiumIndexView(store: store)
                    }
                case .combatantDetail:
                    if let store = store.scope(state: \.content[case: \.combatantDetail], action: \.contentCombatantDetail) {
                        CombatantDetailView(store: store)
                    }
                case .addCombatant:
                    if let store = store.scope(state: \.content[case: \.addCombatant], action: \.contentAddCombatant) {
                        AddCombatantReferenceItemView(store: store)
                    }
                case .compendiumItem:
                    if let store = store.scope(state: \.content[case: \.compendiumItem], action: \.contentCompendiumItem) {
                        CompendiumEntryDetailView(store: store)
                    }
                case .safari:
                    if let store = store.scope(state: \.content[case: \.safari], action: \.contentSafari) {
                        SafariView(url: store.withState(\.url))
                            .navigationBarHidden(true)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        // Work-around for a blank tab when the iPad app is running on a mac
        // Usually, macOS would convert the attempt to show a SFSafariViewController
        // to a link open in Safari. This works on the Settings/About screen, but not here
        // for some reason. So we do it manually.
        .onAppear {
            if let url = store.content[case: \.safari]?.url, ProcessInfo.processInfo.isiOSAppOnMac {
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
