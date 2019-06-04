//
//  RunningEncounter.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 11/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct RunningEncounter: Codable, Equatable {
    let id: UUID
    var base: Encounter // the encounter that was originally run
    var current: Encounter // the current encounter after changes that happened during the run

    var turn: Turn?

    var log: [RunningEncounterEvent] = [] // latest at the end

    var currentTurnCombatant: Combatant? {
        turn.flatMap { t in current.combatant(for: t.combatantId) }
    }

    func turnAfter(_ turn: Turn) -> Turn {
        let order = current.initiativeOrder
        guard let idx = order.firstIndex(where: { $0.id == turn.combatantId }) else { return turn }

        if (idx + 1) < order.count {
            return Turn(round: turn.round, combatantId: order[idx+1].id)
        } else if let first = order.first {
            return Turn(round: turn.round + 1, combatantId: first.id)
        }
        return turn
    }

    func turnBefore(_ turn: Turn) -> Turn {
        let order = current.initiativeOrder
        guard let idx = order.firstIndex(where: { $0.id == turn.combatantId }) else { return turn }
        if (idx > 0) {
            return Turn(round: turn.round, combatantId: order[idx-1].id)
        } else if turn.round > 1, let last = order.last {
            return Turn(round: turn.round - 1, combatantId: last.id)
        }
        return turn
    }

    mutating func nextTurn() {
        self.turn = turn.map(turnAfter)
    }

    mutating func previousTurn() {
        self.turn = turn.map(turnBefore)
    }

    func isTagValid(_ tag: CombatantTag, _ combatant: Combatant) -> Bool {
        guard let turnOfExpiry = tagExpiresAt(tag, combatant) else { return true }
        return isInFuture(turnOfExpiry)
    }

    // If the current turn is equal to or later than the returned turn, the tag has expired
    func tagExpiresAt(_ tag: CombatantTag, _ combatant: Combatant) -> Turn? {
        guard let duration = tag.duration, let start = tag.addedIn else { return nil }

        switch duration {
        case .timeInterval(let dc):
            var round = start.round
            if let m = dc.minute {
                round += m * 10
            }
            if let h = dc.hour {
                round += h * 60 * 10
            }
            return Turn(round: round, combatantId: start.combatantId)
        case .until(let m, skipping: let s):
            let context = EffectContext(running: self, combatant: combatant, tag: tag)

            var since = start
            for _ in 0...s {
                since = firstTurnStart(after: m, since: since, with: context)
            }
            return since
        }
    }

    func firstTurnStart(after moment: EncounterMoment, since turn: Turn, with context: EffectContext) -> Turn {
        let order = current.initiativeOrder
        guard let turnIdx = order.firstIndex(where: { $0.id == turn.combatantId }) else { return turn }

        switch moment {
        case .turnStart(let t):
            guard let cs = t.resolve(in: context),
                let combatant = cs.last,
                let idx = order.firstIndex(where: { $0.id == combatant.id }) else { return turn }

            if idx > turnIdx {
                return Turn(round: turn.round, combatantId: combatant.id)
            } else {
                return Turn(round: turn.round + 1, combatantId: combatant.id)
            }
        case .turnEnd(let t):
            guard let cs = t.resolve(in: context),
                let combatant = cs.last,
                let idx = order.firstIndex(where: { $0.id == combatant.id }) else { return turn }

            if idx >= turnIdx {
                return turnAfter(Turn(round: turn.round, combatantId: combatant.id))
            } else {
                return turnAfter(Turn(round: turn.round + 1, combatantId: combatant.id))
            }
        }
    }

    func isTurn(_ turn: Turn, before otherTurn: Turn) -> Bool {
        if turn.round < otherTurn.round {
            return true
        } else if turn.round > otherTurn.round {
            return false
        } else {
            let order = current.initiativeOrder
            if let tIdx = order.firstIndex(where: { $0.id == turn.combatantId }), let otIdx = order.firstIndex(where: { $0.id == otherTurn.combatantId }) {
                return tIdx < otIdx
            }

            // could not resolve combatants
            return false
        }
    }

    func isInFuture(_ turn: Turn) -> Bool {
        guard let currentTurn = self.turn else { return true }
        return isTurn(currentTurn, before: turn)
    }

    func currentTurn(has moment: EncounterMoment, context: EffectContext) -> Bool {
        guard let currentTurn = self.turn else { return false }
        switch moment {
        case .turnStart:
            return false
        case .turnEnd(let t):
            guard let combatants = t.resolve(in: context) else { return false }
            return combatants.contains { $0.id == currentTurn.combatantId }
        }
    }

    struct Turn: Codable, Hashable {
        let round: Int
        let combatantId: UUID
    }
}

struct RunningEncounterEvent: Codable, Equatable {
    let id: UUID

    var turn: RunningEncounter.Turn

    var combatantEvent: CombatantEvent?

    func involves(_ combatant: Combatant) -> Bool {
        if let event = combatantEvent {
            return event.source?.id == combatant.id || event.target.id == combatant.id
        }
        return false
    }

    struct CombatantEvent: Codable, Equatable {
        let target: CombatantReference
        let source: CombatantReference?

        let effect: Effect

        struct Effect: Codable, Equatable { // should be enum, but struct gives us auto-codable
            let currentHp: Int?
        }
    }

    struct CombatantReference: Codable, Equatable {
        let id: UUID
        let name: String
        let discriminator: Int?
    }
}

extension RunningEncounter {

    static let reducer: Reducer<RunningEncounter, Action, Environment> = Reducer.combine(
        logReducer,
        Reducer { state, action, _ in
            switch action {
            case .current(.remove(let c)):
                if state.turn?.combatantId == c.id {
                    state.nextTurn()
                    if state.turn?.combatantId == c.id {
                        // no other combatant to "turn" to
                        state.turn = nil
                    }
                }
                break
            default:
                break
            }
            return .none
        },
        Encounter.reducer.pullback(state: \.current, action: /Action.current),
        Reducer { state, action, _ in
            switch action {
            case .current(.combatant(let uuid, .addTag(let tag))):
                // annotate added tag with current turn
                if state.current.combatants[id: uuid]?.tags[id: tag.id]?.addedIn == nil {
                    state.current.combatants[id: uuid]?.tags[id: tag.id]?.addedIn = state.turn
                }
                break
            case .current(let action): // also handled by the reducer above
                if state.current.allCombatantsHaveInitiative, state.turn == nil {
                    state.turn = state.current.initiativeOrder.first.map { Turn(round: 1, combatantId: $0.id) }
                }
            case .nextTurn:
                if state.turn != nil {
                    state.nextTurn()
                } else {
                    state.turn = state.current.initiativeOrder.first.map { Turn(round: 1, combatantId: $0.id) }
                }
                break
            case .previousTurn:
                if state.turn != nil {
                    state.previousTurn()
                }
            }
            return .none
        }
    )

    private static let logReducer: Reducer<RunningEncounter, Action, Environment> = Reducer { state, action, _ in
        guard let turn = state.turn else { return .none }

        switch action {
        case .current(.combatant(let uuid, let action)):
            guard let combatant = state.current.combatants[id: uuid] else { return .none }
            switch action {
            case .hp(.current(.add(let hp))):
                state.log.append(RunningEncounterEvent(
                    id: UUID(),
                    turn: turn,
                    combatantEvent: RunningEncounterEvent.CombatantEvent(
                        target: RunningEncounterEvent.CombatantReference(id: uuid, name: combatant.name, discriminator: combatant.discriminator),
                        source: nil,
                        effect: .init(currentHp: hp)
                    )
                ))
            default: break
            }
        default: break
        }
        return .none
    }

    enum Action: Equatable {
        case current(Encounter.Action)
        case nextTurn
        case previousTurn

        var current: Encounter.Action? {
            guard case .current(let a) = self else { return nil }
            return a
        }
    }
}

extension RunningEncounter: KeyValueStoreEntity {
    var key: String {
        return "\(Self.keyPrefix(for: base))\(id)"
    }

    static func keyPrefix(for encounter: Encounter) -> String {
        "\(encounter.key).running."
    }

    static func keyPrefix(for encounterId: UUID) -> String {
        "\(Encounter.key(encounterId)).running."
    }
}

extension RunningEncounter {
    static let nullInstance = RunningEncounter(id: UUID(), base: Encounter.nullInstance, current: Encounter.nullInstance)
}
