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
    var store: Store<AddCombatantFeature.State, AddCombatantFeature.Action>
    var viewStore: ViewStore<AddCombatantFeature.State, AddCombatantFeature.Action>

    let onSelection: (AddCombatantView.Action, _ dismiss: Bool) -> Void

    var body: some View {
        CompendiumIndexView(
            store: store.scope(state: { $0.compendiumState }, action: { .compendiumState($0) }),
            viewProvider: compendiumIndexViewProvider,
            bottomBarButtons: {
                Button(action: {
                    self.viewStore.send(.quickCreate)
                }) {
                    Label("Quick create", systemImage: "plus.circle")
                }
            }
        )
    }

    var compendiumIndexViewProvider: CompendiumIndexViewProvider {
        CompendiumIndexViewProvider(
            row: { store, entry in
                (entry.item as? CompendiumCombatant).map { combatant in
                    CombatantRowView(parent: self, compendiumIndexStore: store, entry: entry, combatant: combatant)
                }.replaceNilWith {
                    (entry.item as? CompendiumItemGroup).map { group in
                        GroupRowView(parent: self, compendiumIndexStore: store, entry: entry, group: group)
                    }.replaceNilWith {
                        CompendiumIndexViewProvider.default.row(store, entry)
                    }
                }.eraseToAnyView
            },
            detail: { store in
                let viewStore = ViewStore(store, observe: \.self)
                guard viewStore.state.item is Monster else { return CompendiumIndexViewProvider.default.detail(store).eraseToAnyView }
                return AddCombatantDetailView(parentStore: self.store, store: store, onSelection: { action in
                    self.onSelection(action, false)
                })
                .navigationBarTitle(Text(viewStore.state.item.title), displayMode: .inline)
                .eraseToAnyView
            },
            state: { [state=viewStore.state] in state.combatantsByDefinitionCache }
        )
    }

    struct CombatantRowView: View {
        var parent: AddCombatantCompendiumView
        var compendiumIndexStore: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>
        @ObservedObject var compendiumIndexViewStore: ViewStore<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>
        let entry: CompendiumEntry
        let combatant: CompendiumCombatant

        init(parent: AddCombatantCompendiumView, compendiumIndexStore: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>, entry: CompendiumEntry, combatant: CompendiumCombatant) {
            self.parent = parent
            self.compendiumIndexStore = compendiumIndexStore
            self.compendiumIndexViewStore = ViewStore(compendiumIndexStore)
            self.entry = entry
            self.combatant = combatant
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(combatant.title).foregroundColor(Color.primary).lineLimit(1)

                    combatant.localizedSummary(in: compendiumIndexViewStore.state, env: parent.env)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }

                Spacer()

                if ViewStore(compendiumIndexStore).properties.showSourceDocumentBadges {
                    Text(entry.document.id.rawValue.uppercased())
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .padding([.leading, .trailing], 2)
                        .background(Color(UIColor.systemFill).clipShape(RoundedRectangle(cornerRadius: 4)))
                }

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
        var compendiumIndexStore: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>
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
        store: Store<AddCombatantFeature.State, AddCombatantFeature.Action>,
        onSelection: @escaping (AddCombatantView.Action, _ dismiss: Bool) -> Void
    ) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
        self.onSelection = onSelection
    }
}
