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
    @Bindable var store: StoreOf<AddCombatantFeature>

    let onSelection: (AddCombatantView.Action, _ dismiss: Bool) -> Void

    init(
        store: StoreOf<AddCombatantFeature>,
        onSelection: @escaping (AddCombatantView.Action, _ dismiss: Bool) -> Void
    ) {
        self.store = store
        self.onSelection = onSelection
    }

    var body: some View {
        CompendiumIndexView(
            store: store.scope(state: \.compendiumState, action: \.compendiumState),
            viewProvider: compendiumIndexViewProvider,
            bottomBarButtons: {
                Button(action: {
                    store.send(.quickCreate)
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
                    CombatantRowView(
                        addCombatantStore: self.store,
                        compendiumIndexStore: store,
                        entry: entry,
                        combatant: combatant,
                        onSelection: onSelection
                    )
                }.replaceNilWith {
                    (entry.item as? CompendiumItemGroup).map { group in
                        GroupRowView(
                            addCombatantStore: self.store,
                            compendiumIndexStore: store,
                            entry: entry,
                            group: group,
                            onSelection: onSelection
                        )
                    }.replaceNilWith {
                        CompendiumIndexViewProvider.default.row(store, entry)
                    }
                }.eraseToAnyView
            },
            detail: { store in
                guard store.item is Monster else { return CompendiumIndexViewProvider.default.detail(store).eraseToAnyView }
                return AddCombatantDetailView(parentStore: self.store, store: store, onSelection: { action in
                    self.onSelection(action, false)
                })
                .navigationBarTitle(Text(store.item.title), displayMode: .inline)
                .eraseToAnyView
            },
            state: { store.combatantsByDefinitionCache }
        )
    }

    struct CombatantRowView: View {
        @EnvironmentObject var ordinalFormatter: OrdinalFormatter

        @Bindable var addCombatantStore: StoreOf<AddCombatantFeature>
        let compendiumIndexStore: StoreOf<CompendiumIndexFeature>
        let entry: CompendiumEntry
        let combatant: CompendiumCombatant

        let onSelection: (AddCombatantView.Action, Bool) -> Void

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(combatant.title).foregroundColor(Color.primary).lineLimit(1)

                    combatant.localizedSummary(in: compendiumIndexStore.state, ordinalFormatter: ordinalFormatter)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }

                Spacer()

                if compendiumIndexStore.properties.showSourceDocumentBadges {
                    Text(entry.document.id.rawValue.uppercased())
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .padding([.leading, .trailing], 2)
                        .background(Color(UIColor.systemFill).clipShape(RoundedRectangle(cornerRadius: 4)))
                }

                HStack(spacing: 6) {
                    with(addCombatantStore.combatantsByDefinitionCache[CompendiumCombatantDefinition.definitionID(for: combatant)]) { def in
                        if def != nil {
                            SimpleAccentedButton(action: {
                                withAnimation {
                                    self.onSelection(.remove(CompendiumCombatantDefinition.definitionID(for: self.combatant), 1), false)
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
                                self.onSelection(.add([Combatant(compendiumCombatant: self.combatant)]), false)
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
        @Bindable var addCombatantStore: StoreOf<AddCombatantFeature>
        var compendiumIndexStore: Store<CompendiumIndexFeature.State, CompendiumIndexFeature.Action>
        let entry: CompendiumEntry
        let group: CompendiumItemGroup
        let onSelection: (AddCombatantView.Action, Bool) -> Void

        var body: some View {
            HStack {
                CompendiumIndexViewProvider.default.row(compendiumIndexStore, entry)
                Spacer()

                with(combatantsNotInEncounter) { combatants in
                    SimpleAccentedButton(action: {
                        self.onSelection(.addByKey(combatants, self.group), false)
                    }) {
                        Image(systemName: "plus.circle")
                            .font(Font.title.weight(.light))
                    }.disabled(combatants.isEmpty).padding(.trailing, 4)
                }
            }
        }

        var combatantsNotInEncounter: [CompendiumItemKey] {
            group.members.filter { member in
                addCombatantStore.combatantsByDefinitionCache[CompendiumCombatantDefinition.definitionID(for: member.itemKey)] == nil
            }.map { $0.itemKey }
        }
    }
}
