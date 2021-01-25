//
//  AddCombatantView.swift
//  SwiftUITest
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

    let onSelection: (Action, _ dismiss: Bool) -> Void

    init(store: Store<AddCombatantState, AddCombatantState.Action>, onSelection: @escaping (Action, _ dismiss: Bool) -> Void) {
        self.store = store
        self.viewStore = ViewStore(store, removeDuplicates: { $0.normalizedForDeduplication == $1.normalizedForDeduplication })
        self.onSelection = onSelection
    }

    var body: some View {
        return VStack(spacing: 0) {
            ZStack {
                NavigationView {
                    AddCombatantCompendiumView(store: store, viewStore: viewStore, onSelection: onSelection)
                    .navigationBarItems(trailing: Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done").bold()
                    })
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

            VStack {
                Divider()

                EncounterDifficultyView(encounter: viewStore.state.encounter)
                    .padding(12)
            }
            .padding(.bottom, 30) // fixme: static value because I can't make this view not ignore the safe area
            .background(Color(UIColor.tertiarySystemBackground))
        }
        .sheet(isPresented: Binding(get: {
            self.viewStore.state.creatureEditViewState != nil
        }, set: {
            if !$0 && self.viewStore.state.creatureEditViewState != nil {
                self.viewStore.send(.onCreatureEditViewDismiss)
            }
        })) {
            IfLetStore(self.store.scope(state: { $0.creatureEditViewState }, action: { .creatureEditView($0) })) { store in
                NavigationView {
                    CreatureEditView(store: store)
                        .navigationBarTitle(Text("Quick create"), displayMode: .inline)
                }
                .environmentObject(self.env)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    enum Action: Equatable {
        case add([Combatant])
        case addByKey([CompendiumItemKey], CompendiumItemGroup) // for adding a party of combatants
        case remove(String, Int) // definition's id & quantity
    }
}
