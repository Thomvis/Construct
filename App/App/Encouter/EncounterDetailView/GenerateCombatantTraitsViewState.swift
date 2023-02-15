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
import CustomDump

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

    var showUndoAllChanges: Bool {
        combatants.first(where: combatantHasChanges) != nil
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

    func combatantHasChanges(_ combatant: CombatantModel) -> Bool {
        guard let changedTraits = traits[combatant.id] else { return false }
        return encounter.combatants[id: combatant.id]?.traits != changedTraits
    }

    func selectedCombatants() -> Set<Combatant.Id> {
        if case .custom(let ids) = selection {
            return ids
        }

        return Set(combatants.filter(isSelected).map { $0.id })
    }

    fileprivate var request: GenerateCombatantTraitsRequest {
        GenerateCombatantTraitsRequest(
            combatantNames: combatants
                .filter(isSelected(combatant:))
                .map(\.discriminatedName)
        )
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
    case onUndoAllChangesTap
    case onToggleCombatantSelection(Combatant.Id)
    case onRemoveCombatantTraitsTap(Combatant.Id)
    case onUndoCombatantTraitsChangesTap(Combatant.Id)
    case onRegenerateCombatantTraitsTap(Combatant.Id)
    case onGenerateTap
    case onTraitGenerationDidReceiveTraits(GenerateCombatantTraitsResponse.Traits)
    case onTraitGenerationDidFinish
    case onTraitGenerationDidFail(MechMuseError)
    case binding(BindingAction<GenerateCombatantTraitsViewState>)

    // handled by the parent
    case onDoneButtonTap
}

typealias GenerateCombatantTraitsViewEnvironment = EnvironmentWithMechMuse & EnvironmentWithCrashReporter

private enum GenerateID { }

extension GenerateCombatantTraitsViewState {
    static let reducer: AnyReducer<Self, GenerateCombatantTraitsViewAction, GenerateCombatantTraitsViewEnvironment> = AnyReducer { state, action, env in

        func perform(
            _ request: GenerateCombatantTraitsRequest,
            _ state: inout Self
        ) -> Effect<GenerateCombatantTraitsViewAction, Never> {
            state.isLoading = true
            state.error = nil
            return .run { send in
                do {
                    let response = try env.mechMuse.describe(combatants: request)
                    for try await traits in response {
                        await send(.onTraitGenerationDidReceiveTraits(traits))
                    }
                    await send(.onTraitGenerationDidFinish)
                } catch let error as MechMuseError {
                    await send(.onTraitGenerationDidFail(error), animation: .default)
                } catch {
                    await send(.onTraitGenerationDidFail(.unspecified), animation: .default)
                }
            }
            .cancellable(id: GenerateID.self)
        }

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
        case .onUndoAllChangesTap:
            state.traits = [:]
        case .onToggleCombatantSelection(let id):
            let ids = state.selectedCombatants()
            if ids.contains(id) {
                state.selection = .custom(ids.subtracting([id]))
            } else if let combatant = state.combatants.first(where: { $0.id == id }), state.canSelect(combatant: combatant) {
                state.selection = .custom(ids.union([id]))
            }
        case .onRemoveCombatantTraitsTap(let id):
            state.traits[id] = .some(nil)
        case .onUndoCombatantTraitsChangesTap(let id):
            state.traits.removeValue(forKey: id)
        case .onRegenerateCombatantTraitsTap(let id):
            guard let combatant = state.combatants.first(where: { $0.id == id }) else { break }
            let request = GenerateCombatantTraitsRequest(combatantNames: [combatant.discriminatedName])
            return perform(request, &state)
        case .onGenerateTap:
            return perform(state.request, &state)
        case .onTraitGenerationDidReceiveTraits(let traits):
            let l = Locale(identifier: "en_US")
            let lowercasedName = traits.name.lowercased(with: l)
            guard let combatant = state.encounter.combatants.first(where: {
                $0.discriminatedName.lowercased(with: l) == lowercasedName
            }) else {
                break
            }

            state.traits[combatant.id] = .init(
                physical: traits.physical,
                personality: traits.personality,
                nickname: traits.nickname,
                generatedByMechMuse: true
            )
        case .onTraitGenerationDidFinish:
            state.overwriteEnabled = false
            state.isLoading = false
        case .onTraitGenerationDidFail(let error):
            var request = ""
            customDump(state.request, to: &request)

            env.crashReporter.trackError(.init(error: error, properties: [:], attachments: [
                "request" : request
            ]))
            state.error = error
            state.isLoading = false
        case .onDoneButtonTap: // handled by the parent
            return .cancel(id: GenerateID.self)
        case .binding: break // handled by the higher-order reducer
        }

        return .none
    }
    .binding()

    static let nullInstance = GenerateCombatantTraitsViewState(encounter: Encounter.nullInstance)
}

