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

struct AddCombatantView: View {
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var store: Store<AddCombatantState, AddCombatantState.Action>
    @ObservedObject var viewStore: ViewStore<AddCombatantState, AddCombatantState.Action>

    let externalNavigation: Bool
    let showEncounterDifficulty: Bool
    let onSelection: (Action, _ dismiss: Bool) -> Void

    init(
        store: Store<AddCombatantState, AddCombatantState.Action>,
        externalNavigation: Bool = false,
        showEncounterDifficulty: Bool = true,
        onSelection: @escaping (Action, _ dismiss: Bool) -> Void
    ) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.localStateForDeduplication == $1.localStateForDeduplication })
        self.externalNavigation = externalNavigation
        self.showEncounterDifficulty = showEncounterDifficulty
        self.onSelection = onSelection
    }

    var body: some View {
        return VStack(spacing: 0) {
            ZStack {
                if externalNavigation {
                    AddCombatantCompendiumView(store: store, viewStore: viewStore, onSelection: onSelection)
                } else {
                    NavigationView {
                        AddCombatantCompendiumView(store: store, viewStore: viewStore, onSelection: onSelection)
                        .navigationBarItems(trailing: Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Done").bold()
                        })
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }

                HStack {
                    RoundedButton(action: {
                        self.viewStore.send(.quickCreate)
                    }) {
                        Label("Quick create", systemImage: "plus.circle")
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom).padding(8)
            }

            if showEncounterDifficulty {
                VStack {
                    Divider()

                    EncounterDifficultyView(encounter: viewStore.state.encounter)
                        .padding(12)
                }
                .padding(.bottom, 30) // fixme: static value because I can't make this view not ignore the safe area
                .background(Color(UIColor.tertiarySystemBackground))
            }
        }
        .sheet(isPresented: Binding(get: {
            self.viewStore.state.creatureEditViewState != nil
        }, set: {
            if !$0 && self.viewStore.state.creatureEditViewState != nil {
                self.viewStore.send(.onCreatureEditViewDismiss)
            }
        })) {
            IfLetStore(self.store.scope(state: replayNonNil({ $0.creatureEditViewState }), action: { .creatureEditView($0) })) { store in
                SheetNavigationContainer(isModalInPresentation: true) {
                    CreatureEditView(store: store)
                        .navigationBarTitle(Text("Quick create"), displayMode: .inline)
                }
                .environmentObject(self.env)
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
