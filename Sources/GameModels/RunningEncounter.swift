//
//  RunningEncounter.swift
//  Construct
//
//  Created by Thomas Visser on 11/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Tagged

public struct RunningEncounter: Codable, Equatable {
    public let id: Id
    public var base: Encounter // the encounter that was originally run
    public var current: Encounter // the current encounter after changes that happened during the run

    public var turn: Turn?

    public var log: [RunningEncounterEvent] = [] // latest at the end

    public var currentTurnCombatant: Combatant? {
        turn.flatMap { t in current.combatant(for: t.combatantId) }
    }

    public init(id: Id, base: Encounter, current: Encounter, turn: Turn? = nil, log: [RunningEncounterEvent] = []) {
        self.id = id
        self.base = base
        self.current = current
        self.turn = turn
        self.log = log
    }

    public func turnAfter(_ turn: Turn) -> Turn {
        let order = current.initiativeOrder
        guard let idx = order.firstIndex(where: { $0.id == turn.combatantId }) else { return turn }

        if (idx + 1) < order.count {
            return Turn(round: turn.round, combatantId: order[idx+1].id)
        } else if let first = order.first {
            return Turn(round: turn.round + 1, combatantId: first.id)
        }
        return turn
    }

    public func turnBefore(_ turn: Turn) -> Turn {
        let order = current.initiativeOrder
        guard let idx = order.firstIndex(where: { $0.id == turn.combatantId }) else { return turn }
        if (idx > 0) {
            return Turn(round: turn.round, combatantId: order[idx-1].id)
        } else if turn.round > 1, let last = order.last {
            return Turn(round: turn.round - 1, combatantId: last.id)
        }
        return turn
    }

    public mutating func nextTurn() {
        self.turn = turn.map(turnAfter)
    }

    public mutating func previousTurn() {
        self.turn = turn.map(turnBefore)
    }

    public func isTagValid(_ tag: CombatantTag, _ combatant: Combatant) -> Bool {
        guard let turnOfExpiry = tagExpiresAt(tag, combatant) else { return true }
        return isInFuture(turnOfExpiry)
    }

    // If the current turn is equal to or later than the returned turn, the tag has expired
    public func tagExpiresAt(_ tag: CombatantTag, _ combatant: Combatant) -> Turn? {
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

    public func firstTurnStart(after moment: EncounterMoment, since turn: Turn, with context: EffectContext) -> Turn {
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

    public func isTurn(_ turn: Turn, before otherTurn: Turn) -> Bool {
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

    public func isInFuture(_ turn: Turn) -> Bool {
        guard let currentTurn = self.turn else { return true }
        return isTurn(currentTurn, before: turn)
    }

    public func currentTurn(has moment: EncounterMoment, context: EffectContext) -> Bool {
        guard let currentTurn = self.turn else { return false }
        switch moment {
        case .turnStart:
            return false
        case .turnEnd(let t):
            guard let combatants = t.resolve(in: context) else { return false }
            return combatants.contains { $0.id == currentTurn.combatantId }
        }
    }

    public typealias Id = Tagged<RunningEncounter, UUID>

    public struct Turn: Codable, Hashable {
        public let round: Int
        public let combatantId: Combatant.Id

        public init(round: Int, combatantId: Combatant.Id) {
            self.round = round
            self.combatantId = combatantId
        }
    }
}

public struct RunningEncounterEvent: Codable, Equatable {
    public let id: Id

    public var turn: RunningEncounter.Turn

    public var combatantEvent: CombatantEvent?

    public init(id: Id, turn: RunningEncounter.Turn, combatantEvent: CombatantEvent? = nil) {
        self.id = id
        self.turn = turn
        self.combatantEvent = combatantEvent
    }

    public func involves(_ combatant: Combatant) -> Bool {
        if let event = combatantEvent {
            return event.source?.id == combatant.id || event.target.id == combatant.id
        }
        return false
    }

    public typealias Id = Tagged<RunningEncounterEvent, UUID>

    public struct CombatantEvent: Codable, Equatable {
        public let target: CombatantReference
        public let source: CombatantReference?

        public let effect: Effect

        public init(target: CombatantReference, source: CombatantReference?, effect: Effect) {
            self.target = target
            self.source = source
            self.effect = effect
        }

        public struct Effect: Codable, Equatable { // should be enum, but struct gives us auto-codable
            public let currentHp: Int?

            public init(currentHp: Int?) {
                self.currentHp = currentHp
            }
        }
    }

    public struct CombatantReference: Codable, Equatable {
        public let id: Combatant.Id
        public let name: String
        public let discriminator: Int?

        public init(id: Combatant.Id, name: String, discriminator: Int?) {
            self.id = id
            self.name = name
            self.discriminator = discriminator
        }
    }
}

extension RunningEncounter {
    public static let nullInstance = RunningEncounter(id: UUID().tagged(), base: Encounter.nullInstance, current: Encounter.nullInstance)
}
