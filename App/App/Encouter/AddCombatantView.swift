//
//  AddCombatantView.swift
//  Construct
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import SharedViews

struct AddCombatantView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @Bindable var store: StoreOf<AddCombatantFeature>

    let externalNavigation: Bool
    let showEncounterDifficulty: Bool
    let onSelection: (Action, _ dismiss: Bool) -> Void

    init(
        store: StoreOf<AddCombatantFeature>,
        externalNavigation: Bool = false,
        showEncounterDifficulty: Bool = true,
        onSelection: @escaping (Action, _ dismiss: Bool) -> Void
    ) {
        self.store = store
        self.externalNavigation = externalNavigation
        self.showEncounterDifficulty = showEncounterDifficulty
        self.onSelection = onSelection
    }

    var body: some View {
        return VStack(spacing: 0) {
            ZStack {
                if externalNavigation {
                    AddCombatantCompendiumView(store: store, onSelection: onSelection)
                } else {
                    NavigationStack {
                        AddCombatantCompendiumView(store: store, onSelection: onSelection)
                        .navigationBarItems(trailing: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Done").bold()
                        })
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }

            if showEncounterDifficulty {
                VStack {
                    Divider()

                    EncounterDifficultyView(encounter: store.encounter)
                        .padding(12)
                }
                .padding(.bottom, 30) // fixme: static value because I can't make this view not ignore the safe area
                .background(Color(UIColor.tertiarySystemBackground))
            }
        }
        .sheet(
            store: store.scope(state: \.$creatureEditViewState, action: \.creatureEditView)
        ) { creatureStore in
            SheetNavigationContainer(isModalInPresentation: true) {
                CreatureEditView(store: creatureStore)
                    .navigationBarTitle(Text("Quick create"), displayMode: .inline)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    enum Action: Equatable {
        case add([Combatant])
        case addByKey([CompendiumItemKey], CompendiumItemGroup) // for adding a party of combatants
        case remove(String, Int) // definition's id & quantity
    }
}
