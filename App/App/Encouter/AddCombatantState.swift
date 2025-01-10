//
//  AddCombatantState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Helpers
import GameModels

typealias AddCombatantEnvironment = CompendiumIndexEnvironment & CreatureEditViewEnvironment

struct AddCombatantState: Equatable {
    var compendiumState: CompendiumIndexState

    var encounter: Encounter {
        didSet {
            updateCombatantsByDefinitionCache()
            updateSuggestedCombatants()
        }
    }
    var creatureEditViewState: CreatureEditViewState?

    var combatantsByDefinitionCache: [String: [Combatant]] = [:] // computed from the encounter

    private mutating func updateCombatantsByDefinitionCache() {
        var result: [String: [Combatant]] = [:]
        for combatant in encounter.combatants {
            result[combatant.definition.definitionID, default: []].append(combatant)
        }
        self.combatantsByDefinitionCache = result
    }

    /// Suggestions are built from the encounter. Each non-unique compendium combatant is a suggested combatant
    /// If a combatant is removed from the encounter, it is not removed from the suggestions. (Until a whole new state
    /// is created.)
    private mutating func updateSuggestedCombatants() {
        let newSuggestions = combatantsByDefinitionCache.values.compactMap { combatants in
            combatants.first?.definition as? CompendiumCombatantDefinition
        }.compactMap { definition -> CompendiumEntry? in
            if !definition.isUnique {
                // FIXME: we don't have all the info here to properly create the entry
                return CompendiumEntry(
                    definition.item,
                    origin: .created(.init(definition.item)),
                    document: .init(
                        id: CompendiumSourceDocument.unspecifiedCore.id,
                        displayName: CompendiumSourceDocument.unspecifiedCore.displayName
                    )
                )
            }
            return nil
        }.filter { c in !(compendiumState.suggestions?.contains(where: { $0.key == c.key }) ?? false) }

        compendiumState.suggestions = compendiumState.suggestions.map { $0 + newSuggestions } ?? newSuggestions.nonEmptyArray
    }

    var localStateForDeduplication: Self {
        return AddCombatantState(
            compendiumState: CompendiumIndexState.nullInstance,
            encounter: self.encounter,
            creatureEditViewState: self.creatureEditViewState.map { _ in CreatureEditViewState.nullInstance }
        )
    }

    enum Action: Equatable {
        case compendiumState(CompendiumIndexAction)
        case quickCreate
        case creatureEditView(CreatureEditViewAction)
        case onCreatureEditViewDismiss
        case onSelect([Combatant], dismiss: Bool)
    }

    static var reducer: AnyReducer<AddCombatantState, AddCombatantState.Action, AddCombatantEnvironment> {
        AnyReducer.combine(
            CreatureEditViewState.reducer.optional().pullback(
                state: \.creatureEditViewState,
                action: /Action.creatureEditView,
                environment: { $0 }
            ),
            AnyReducer { state, action, _ in
                switch action {
                case .quickCreate:
                    state.creatureEditViewState = CreatureEditViewState(create: .adHocCombatant)
                case .creatureEditView(.onAddTap(let s)):
                    state.creatureEditViewState = nil
                    if let combatant = s.adHocCombatant {
                        return .send(.onSelect([Combatant(adHoc: combatant)], dismiss: true))
                    }
                case .creatureEditView: break // handled below
                case .onCreatureEditViewDismiss:
                    state.creatureEditViewState = nil
                case .compendiumState: break
                case .onSelect: break // should be handled by parent
                }
                return .none
            },
            CompendiumIndexState.reducer.pullback(
                state: \.compendiumState,
                action: /Action.compendiumState,
                environment: { $0 }
            )
        )
    }
}

extension AddCombatantState {
    static let nullInstance = AddCombatantState(encounter: Encounter.nullInstance)

    init(
        compendiumState: CompendiumIndexState = CompendiumIndexState(
            title: "Add Combatant",
            properties: CompendiumIndexState.Properties(
                showImport: false,
                showAdd: false,
                typeRestriction: [.monster, .character, .group]
            ),
            results: .initial(types: [.monster, .character, .group])
        ),
        encounter: Encounter,
        creatureEditViewState: CreatureEditViewState? = nil
    ) {
        self.compendiumState = compendiumState
        self.encounter = encounter
        self.creatureEditViewState = creatureEditViewState

        updateCombatantsByDefinitionCache()
        updateSuggestedCombatants()
    }
}

extension AddCombatantState: NavigationNode {
    var nodeId: String {
        "AddCombatantState"
    }

    func topNavigationItems() -> [Any] {
        compendiumState.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        compendiumState.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        compendiumState.popLastNavigationStackItem()
    }
}
