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
        self.viewStore = ViewStore(store)
        self.onSelection = onSelection
    }

    var body: some View {
        return VStack(spacing: 0) {
            ZStack {
                NavigationView {
                    CompendiumIndexView(store: store.scope(state: { $0.compendiumState }, action: { .compendiumState($0) }), viewProvider: compendiumIndexViewProvider)
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
            if !$0 { self.viewStore.send(.onCreatureEditViewDismiss) }
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

    var compendiumIndexViewProvider: CompendiumIndexView.ViewProvider {
        CompendiumIndexView.ViewProvider(
            row: { store, entry in
                (entry.item as? CompendiumCombatant).map { combatant in
                    CombatantRowView(parent: self, compendiumIndexStore: store, combatant: combatant)
                }.replaceNilWith {
                    (entry.item as? CompendiumItemGroup).map { group in
                        GroupRowView(parent: self, compendiumIndexStore: store, entry: entry, group: group)
                    }.replaceNilWith {
                        CompendiumIndexView.ViewProvider.default.row(store, entry)
                    }
                }.eraseToAnyView
            },
            detail: { store in
                guard ViewStore(store).state.item is Monster else { return CompendiumIndexView.ViewProvider.default.detail(store).eraseToAnyView }
                return AddCombatantDetailView(parentStore: self.store, store: store, onSelection: { action in
                    self.onSelection(action, false)
                })
                .navigationBarTitle(Text(ViewStore(store).state.item.title), displayMode: .inline)
                .eraseToAnyView
            }
        )
    }

    struct CombatantRowView: View {
        var parent: AddCombatantView
        var compendiumIndexStore: Store<CompendiumIndexState, CompendiumIndexAction>
        @ObservedObject var compendiumIndexViewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>
        let combatant: CompendiumCombatant

        init(parent: AddCombatantView, compendiumIndexStore: Store<CompendiumIndexState, CompendiumIndexAction>, combatant: CompendiumCombatant) {
            self.parent = parent
            self.compendiumIndexStore = compendiumIndexStore
            self.compendiumIndexViewStore = ViewStore(compendiumIndexStore)
            self.combatant = combatant
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(combatant.title)
                    combatant.localizedSummary(in: compendiumIndexViewStore.state, env: parent.env).font(.footnote).foregroundColor(Color(UIColor.secondaryLabel))
                }

                Spacer()

                HStack(spacing: 6) {
                    with(parent.viewStore.state.combatantsByDefinitionCache[CompendiumCombatantDefinition.definitionID(for: combatant)]) { def in
                        if def != nil {
                            SimpleAccentedButton(action: {
                                withAnimation {
                                    self.parent.onSelection(.remove(CompendiumCombatantDefinition.definitionID(for: self.combatant), 1), false)
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(Font.title.weight(.light))
                            }

                            ZStack {
                                Text("\(def?.count ?? 0)")
                                Text("99").opacity(0) // to reserve space
                            }.foregroundColor(Color.accentColor).font(.headline)
                        }

                        SimpleAccentedButton(action: {
                            withAnimation {
                                self.parent.onSelection(.add([Combatant(compendiumCombatant: self.combatant)]), false)
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(Font.title.weight(.light))
                        }.disabled(combatant.isUnique && def != nil)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    struct GroupRowView: View {
        var parent: AddCombatantView
        var compendiumIndexStore: Store<CompendiumIndexState, CompendiumIndexAction>
        let entry: CompendiumEntry
        let group: CompendiumItemGroup

        var body: some View {
            HStack {
                CompendiumIndexView.ViewProvider.default.row(compendiumIndexStore, entry)
                Spacer()

                with(combatantsNotInEncounter) { combatants in
                    SimpleAccentedButton(action: {
                        self.parent.onSelection(.addByKey(combatants, self.group), false)
                    }) {
                        Image(systemName: "plus.circle")
                            .font(Font.title.weight(.light))
                    }.disabled(combatants.isEmpty).padding(.trailing, 4)
                }
            }
        }

        var combatantsNotInEncounter: [CompendiumItemKey] {
            group.members.filter { member in
                parent.viewStore.state.combatantsByDefinitionCache[CompendiumCombatantDefinition.definitionID(for: member.itemKey)] == nil
            }.map { $0.itemKey }
        }
    }

    enum Action {
        case add([Combatant])
        case addByKey([CompendiumItemKey], CompendiumItemGroup) // for adding a party of combatants
        case remove(String, Int) // definition's id & quantity
    }
}
