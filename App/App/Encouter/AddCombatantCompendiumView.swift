//
//  AddCombatantCompendiumView.swift
//  Construct
//
//  Created by Thomas Visser on 25/01/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews
import Helpers
import GameModels

struct AddCombatantCompendiumView: View {
    @EnvironmentObject var env: Environment
    var store: Store<AddCombatantState, AddCombatantState.Action>
    @ObservedObject var viewStore: ViewStore<AddCombatantState, AddCombatantState.Action>

    let onSelection: (AddCombatantView.Action, _ dismiss: Bool) -> Void

    var body: some View {
        WithViewStore(store) { viewStore in
            CompendiumIndexView(
                store: store.scope(state: { $0.compendiumState }, action: { .compendiumState($0) }),
                viewProvider: compendiumIndexViewProvider,
                bottomBarButtons: {
                    RoundedButton(action: {
                        self.viewStore.send(.quickCreate)
                    }) {
                        Label("Quick create", systemImage: "plus.circle")
                    }
                }
            )
        }
    }

    var compendiumIndexViewProvider: CompendiumIndexViewProvider {
        CompendiumIndexViewProvider(
            row: { store, entry in
                (entry.item as? CompendiumCombatant).map { combatant in
                    CombatantRowView(parent: self, compendiumIndexStore: store, combatant: combatant)
                }.replaceNilWith {
                    (entry.item as? CompendiumItemGroup).map { group in
                        GroupRowView(parent: self, compendiumIndexStore: store, entry: entry, group: group)
                    }.replaceNilWith {
                        CompendiumIndexViewProvider.default.row(store, entry)
                    }
                }.eraseToAnyView
            },
            detail: { store in
                guard ViewStore(store).state.item is Monster else { return CompendiumIndexViewProvider.default.detail(store).eraseToAnyView }
                return AddCombatantDetailView(parentStore: self.store, store: store, onSelection: { action in
                    self.onSelection(action, false)
                })
                .navigationBarTitle(Text(ViewStore(store).state.item.title), displayMode: .inline)
                .eraseToAnyView
            }
        )
    }

    struct CombatantRowView: View {
        var parent: AddCombatantCompendiumView
        var compendiumIndexStore: Store<CompendiumIndexState, CompendiumIndexAction>
        @ObservedObject var compendiumIndexViewStore: ViewStore<CompendiumIndexState, CompendiumIndexAction>
        let combatant: CompendiumCombatant

        init(parent: AddCombatantCompendiumView, compendiumIndexStore: Store<CompendiumIndexState, CompendiumIndexAction>, combatant: CompendiumCombatant) {
            self.parent = parent
            self.compendiumIndexStore = compendiumIndexStore
            self.compendiumIndexViewStore = ViewStore(compendiumIndexStore)
            self.combatant = combatant
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(combatant.title).foregroundColor(Color.primary)
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
        var parent: AddCombatantCompendiumView
        var compendiumIndexStore: Store<CompendiumIndexState, CompendiumIndexAction>
        let entry: CompendiumEntry
        let group: CompendiumItemGroup

        var body: some View {
            HStack {
                CompendiumIndexViewProvider.default.row(compendiumIndexStore, entry)
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
}

extension AddCombatantCompendiumView {
    init(
        store: Store<AddCombatantState, AddCombatantState.Action>,
        onSelection: @escaping (AddCombatantView.Action, _ dismiss: Bool) -> Void
    ) {
        self.store = store
        self.viewStore = ViewStore(store)
        self.onSelection = onSelection
    }
}
