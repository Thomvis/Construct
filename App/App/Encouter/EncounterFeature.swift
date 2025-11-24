//
//  EncounterFeature.swift
//  Construct
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels
import ComposableArchitecture
import Helpers
import Compendium

@Reducer
struct EncounterFeature {
    typealias State = Encounter

    @CasePathable
    enum Action: Equatable {
        case name(String)
        case combatant(IdentifiedActionOf<CombatantFeature>)
        case initiative(InitiativeSettings)
        case add(Combatant)
        case addByKey(CompendiumItemKey, CompendiumItemGroup?)
        case remove(Combatant)
        case duplicate(Combatant)
        case partyForDifficulty(Encounter.Party)
        case refreshCompendiumItems
    }

    @Dependency(\.compendium) var compendium
    @Dependency(\.crashReporter) var crashReporter

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
            case .name(let n):
                state.name = n
            case .combatant: break
            case .initiative(let settings):
                var mutableRng = SystemRandomNumberGenerator()
                state.rollInitiative(settings: settings, rng: &mutableRng)
            case .add(let combatant):
                state.combatants.append(combatant)
            case .addByKey(let key, let party):
                return .run { send in
                    do {
                        if let entry = try compendium.get(key, crashReporter: crashReporter),
                           let combatant = entry.item as? CompendiumCombatant {
                            let combatant = Combatant(
                                compendiumCombatant: combatant,
                                party: party.map { CompendiumItemReference(itemTitle: $0.title, itemKey: $0.key) }
                            )
                            await send(.add(combatant))
                        }
                    } catch { }
                }
            case .remove(let combatant):
                if let idx = state.combatants.firstIndex(where: { $0.id == combatant.id }) {
                    state.combatants.remove(at: idx)
                }
            case .duplicate(let combatant):
                let idx = state.combatants.firstIndex(where: { $0.id == combatant.id }) ?? (state.combatants.count - 1)
                state.combatants.insert(
                    Combatant(
                        discriminator: nil,
                        definition: combatant.definition,
                        hp: combatant.hp,
                        resources: combatant.resources.elements,
                        initiative: combatant.initiative
                    ),
                    at: idx + 1
                )
            case .partyForDifficulty(let p):
                state.partyForDifficulty = p
            case .refreshCompendiumItems:
                return .merge(
                    state.combatants.compactMap { combatant in
                        if var def = combatant.definition as? CompendiumCombatantDefinition,
                           let entry = try? compendium.get(def.item.key, crashReporter: crashReporter),
                           let item = entry.item as? CompendiumCombatant {
                            def.item = item
                            return .send(
                                .combatant(
                                    .element(
                                        id: combatant.id,
                                        action: .setDefinition(Combatant.CodableCombatDefinition(definition: def))
                                    )
                                )
                            )
                        }
                        return nil
                    }
                )
            }
            return .none
        }
        .forEach(\.combatants, action: \.combatant) {
            CombatantFeature()
        }
    }
}

extension RunningEncounter {
    @CasePathable
    enum Action: Equatable {
        case current(EncounterFeature.Action)
        case nextTurn
        case previousTurn

        var current: EncounterFeature.Action? {
            guard case .current(let a) = self else { return nil }
            return a
        }
    }
}

extension RunningEncounter {
    struct Reducer: ComposableArchitecture.Reducer {
        typealias State = RunningEncounter
        typealias Action = RunningEncounter.Action

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                guard let turn = state.turn else { return .none }

                switch action {
                case .current(.combatant(.element(let uuid, let action))):
                    guard let combatant = state.current.combatants[id: uuid] else { return .none }
                    switch action {
                    case .hp(.current(.add(let hp))):
                        state.log.append(
                            RunningEncounterEvent(
                                id: UUID().tagged(),
                                turn: turn,
                                combatantEvent: RunningEncounterEvent.CombatantEvent(
                                    target: .init(id: uuid, name: combatant.name, discriminator: combatant.discriminator),
                                    source: nil,
                                    effect: .init(currentHp: hp)
                                )
                            )
                        )
                    default:
                        break
                    }
                default:
                    break
                }
                return .none
            }

            Reduce { state, action in
                switch action {
                case .current(.remove(let c)):
                    if state.turn?.combatantId == c.id {
                        state.nextTurn()
                        if state.turn?.combatantId == c.id {
                            state.turn = nil
                        }
                    }
                default:
                    break
                }
                return .none
            }

            Scope(state: \.current, action: \.current) {
                EncounterFeature()
            }

            Reduce { state, action in
                switch action {
                case .current(.combatant(.element(let uuid, .addTag(let tag)))):
                    if state.current.combatants[id: uuid]?.tags[id: tag.id]?.addedIn == nil {
                        state.current.combatants[id: uuid]?.tags[id: tag.id]?.addedIn = state.turn
                    }
                case .current:
                    if state.current.allCombatantsHaveInitiative, state.turn == nil {
                        state.turn = state.current.initiativeOrder.first.map { Turn(round: 1, combatantId: $0.id) }
                    }
                case .nextTurn:
                    if state.turn != nil {
                        state.nextTurn()
                    } else {
                        state.turn = state.current.initiativeOrder.first.map { Turn(round: 1, combatantId: $0.id) }
                    }
                case .previousTurn:
                    if state.turn != nil {
                        state.previousTurn()
                    }
                }
                return .none
            }
        }
    }
}
