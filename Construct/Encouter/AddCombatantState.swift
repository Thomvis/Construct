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
    var compendiumState: CompendiumIndexState = CompendiumIndexState(title: "Add Combatant", properties: CompendiumIndexState.Properties(showImport: false, showAdd: false, initialContent: .initial(types: [.monster, .character, .group], destinationProperties: .init(showImport: false, showAdd: false, initialContent: .searchResults))), results: .initial(types: [.monster, .character, .group]))

    var encounter: Encounter {
        didSet { updateCombatantsByDefinitionCache() }
    }
    var creatureEditViewState: CreatureEditViewState?

    var combatantsByDefinitionCache: [String: [Combatant]] = [:] // computed from the encounter

    init(encounter: Encounter, creatureEditViewState: CreatureEditViewState? = nil) {
        self.encounter = encounter
        self.creatureEditViewState = creatureEditViewState

        updateCombatantsByDefinitionCache()
    }

    private mutating func updateCombatantsByDefinitionCache() {
        var result: [String: [Combatant]] = [:]
        for combatant in encounter.combatants {
            result[combatant.definition.definitionID, default: []].append(combatant)
        }
        self.combatantsByDefinitionCache = result
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
}
