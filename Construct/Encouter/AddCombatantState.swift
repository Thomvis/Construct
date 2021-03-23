//
//  AddCombatantState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

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
        if case .toc(let toc) = compendiumState.properties.initialContent {
            let newSuggestions = combatantsByDefinitionCache.values.compactMap { combatants in
                combatants.first?.definition as? CompendiumCombatantDefinition
            }.compactMap { definition -> CompendiumEntry? in
                if !definition.isUnique {
                    // FIXME: we don't have all the info here to properly create the entry
                    return CompendiumEntry(definition.item)
                }
                return nil
            }.filter { c in !toc.suggested.contains(where: { $0.key == c.key })}

            let toc = CompendiumIndexState.Properties.ContentDefinition.Toc(
                types: toc.types,
                destinationProperties: toc.destinationProperties,
                suggested: toc.suggested + newSuggestions
            )
            compendiumState.properties.initialContent = .toc(toc)
        }
    }

    var normalizedForDeduplication: Self {
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

    static var reducer: Reducer<AddCombatantState, AddCombatantState.Action, Environment> {
        Reducer.combine(
            CreatureEditViewState.reducer.optional().pullback(state: \.creatureEditViewState, action: /Action.creatureEditView),
            Reducer { state, action, _ in
                switch action {
                case .quickCreate:
                    state.creatureEditViewState = CreatureEditViewState(create: .adHocCombatant)
                case .creatureEditView(.onAddTap(let s)):
                    state.creatureEditViewState = nil
                    if let combatant = s.adHocCombatant {
                        return Effect(value: .onSelect([Combatant(adHoc: combatant)], dismiss: true))
                    }
                case .creatureEditView: break // handled below
                case .onCreatureEditViewDismiss:
                    state.creatureEditViewState = nil
                case .compendiumState: break
                case .onSelect: break // should be handled by parent
                }
                return .none
            },
            CompendiumIndexState.reducer.pullback(state: \.compendiumState, action: /Action.compendiumState)
        )
    }
}

extension AddCombatantState {
    static let nullInstance = AddCombatantState(encounter: Encounter.nullInstance)

    init(
        compendiumState: CompendiumIndexState = CompendiumIndexState(title: "Add Combatant", properties: CompendiumIndexState.Properties(showImport: false, showAdd: false, initiallyFocusOnSearch: false, initialContent: .initial(types: [.monster, .character, .group], destinationProperties: .init(showImport: false, showAdd: false, initiallyFocusOnSearch: false, initialContent: .searchResults))), results: .initial(types: [.monster, .character, .group])),
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
