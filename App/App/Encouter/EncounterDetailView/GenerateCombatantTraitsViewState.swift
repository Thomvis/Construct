//
//  GenerateCombatantTraitsView.swift
//  Construct
//
//  Created by Thomas Visser on 03/01/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels
import ComposableArchitecture
import Helpers
import MechMuse

struct GenerateCombatantTraitsViewState: Equatable {
    private let encounter: Encounter
    // contains an entry for each combatant that got new traits or got its traits removed
    var traits: [Combatant.Id: Combatant.Traits?] = [:]

    var selection: Selection = .smart(.monsters)
    var overwriteEnabled: Bool = false

    var error: MechMuseError?
    var isLoading: Bool = false

    public init(encounter: Encounter, isMechMuseConfigured: Bool = true) {
        self.encounter = encounter
        if !isMechMuseConfigured {
            error = .unconfigured
        }
    }

    var combatants: [CombatantModel] {
        encounter.combatantsInDisplayOrder.map { c in
            .init(
                id: c.id,
                name: c.name,
                traits: traits[c.id] ?? c.traits,
                discriminator: c.discriminator,
                isPlayerCharacter: c.definition.player != nil
            )
        }
    }

    var isMechMuseUnconfigured: Bool {
        error == .unconfigured
    }

    var disableInteractions: Bool {
        isLoading || isMechMuseUnconfigured
    }

    var showRemoveAllTraits: Bool {
        combatants.first { $0.traits != nil } != nil
    }

    func canSelect(combatant: CombatantModel) -> Bool {
        overwriteEnabled || combatant.traits == nil
    }

    func isSelected(combatant: CombatantModel) -> Bool {
        guard canSelect(combatant: combatant) else { return false }

        switch selection {
        case .custom(let ids): return ids.contains { $0 == combatant.id }
        case .smart(let group): return isCombatant(combatant, in: group)
        }
    }

    func isCombatant(_ combatant: CombatantModel, in group: Selection.Group) -> Bool {
        switch group {
        case .monsters: return !combatant.isPlayerCharacter
        case .mobs: return combatant.discriminator != nil
        }
    }

    func selectedCombatants() -> Set<Combatant.Id> {
        if case .custom(let ids) = selection {
            return ids
        }

        return Set(combatants.filter(isSelected).map { $0.id })
    }

    struct CombatantModel: Equatable, Identifiable {
        let id: Combatant.Id
        let name: String
        let traits: Combatant.Traits?
        let discriminator: Int?
        let isPlayerCharacter: Bool

        var discriminatedName: String {
            Combatant.discriminatedName(name, discriminator: discriminator)
        }
    }

    enum Selection: Equatable {
        case smart(Group)
        case custom(Set<Combatant.Id>)

        enum Group: Equatable {
            case monsters
            case mobs
        }
    }
}

enum GenerateCombatantTraitsViewAction: BindableAction, Equatable {
    typealias State = GenerateCombatantTraitsViewState

    case onSmartSelectionGroupTap(State.Selection.Group)
    case onOverwriteButtonTap
    case onRemoveAllTraitsTap
    case onToggleCombatantSelection(Combatant.Id)
    case onRemoveCombatantTraitsTap(Combatant.Id)
    case onGenerateTap
    case didGenerate(Result<GeneratedCombatantTraits, MechMuseError>)
    case binding(BindingAction<GenerateCombatantTraitsViewState>)

    // handled by the parent
    case onCancelButtonTap
    case onDoneButtonTap
}

typealias GenerateCombatantTraitsViewEnvironment = EnvironmentWithMechMuse

extension GenerateCombatantTraitsViewState {
    static let reducer: Reducer<Self, GenerateCombatantTraitsViewAction, GenerateCombatantTraitsViewEnvironment> = Reducer { state, action, env in

        switch action {
        case .onSmartSelectionGroupTap(let g):
            if state.selection == .smart(g) { // already selected
                state.selection = .custom([])
            } else {
                state.selection = .smart(g)
            }
        case .onOverwriteButtonTap:
            state.overwriteEnabled = !state.overwriteEnabled

            if !state.overwriteEnabled, case .custom(let ids) = state.selection {
                // remove combatants that would be overridden
                state.selection = .custom(ids.filter { id in
                    state.encounter.combatants[id: id]?.traits == nil
                })
            }
            break
        case .onRemoveAllTraitsTap:
            for c in state.combatants {
                state.traits[c.id] = .some(nil)
            }
        case .onToggleCombatantSelection(let id):
            let ids = state.selectedCombatants()
            if ids.contains(id) {
                state.selection = .custom(ids.subtracting([id]))
            } else {
                state.selection = .custom(ids.union([id]))
            }
        case .onRemoveCombatantTraitsTap(let id):
            state.traits[id] = .some(nil)
        case .onGenerateTap:
            state.isLoading = true
            state.error = nil
            let request = GenerateCombatantTraitsRequest(
                combatantNames: state.combatants
                    .filter(state.isSelected(combatant:))
                    .map(\.discriminatedName)
            )
            return Effect.run { send in
                do {
                    let descriptions = try await env.mechMuse.describe(combatants: request)
                    await send(.didGenerate(.success(descriptions)), animation: .default)
                } catch let error as MechMuseError {
                    await send(.didGenerate(.failure(error)), animation: .default)
                } catch {
                    await send(.didGenerate(.failure(.unexpected(error.localizedDescription))), animation: .default)
                }
            }
        case .didGenerate(let result):
            switch result {
            case .success(let traits):
                for c in state.encounter.combatants {
                    if let d = traits.traits[c.discriminatedName] {
                        state.traits[c.id] = .init(
                            physical: d.physical,
                            personality: d.personality,
                            nickname: d.nickname,
                            generatedByMechMuse: true
                        )
                    }
                }
                state.overwriteEnabled = false
            case .failure(let error):
                state.error = error
            }

            state.isLoading = false
        case .onCancelButtonTap, .onDoneButtonTap: break // handled by the parent
        case .binding: break // handled by the higher-order reducer
        }

        return .none
    }
    .binding()

    static let nullInstance = GenerateCombatantTraitsViewState(encounter: Encounter.nullInstance)
}

