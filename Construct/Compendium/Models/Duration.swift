//
//  Duration.swift
//  Construct
//
//  Created by Thomas Visser on 13/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

enum EffectDuration: Hashable {
    case timeInterval(DateComponents)
    case until(EncounterMoment, skipping: Int) // if skipping is 0, this means "until _next_ moment"
}

enum EncounterMoment: Hashable {
    case turnStart(Turn)
    case turnEnd(Turn)

    enum Turn: Hashable {
        // relative to usage of this moment turn
        case source
        case target

        case combatant(Combatant.Id)
    }
}

struct EffectContext: Equatable {
    let source: Combatant?
    let targets: [Combatant]
    let running: RunningEncounter

    var combatants: [Combatant] {
        running.current.combatants.elements
    }
}

extension EffectDuration: Codable {
    enum CodingKeys: CodingKey {
        case timeInterval
        case untilMoment
        case untilSkipping
    }

    enum CodableError: Error {
        case unrecognizedDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let dc = try? container.decode(DateComponents.self, forKey: .timeInterval) {
            self = .timeInterval(dc)
        } else if let m = try? container.decode(EncounterMoment.self, forKey: .untilMoment),
            let s = try? container.decode(Int.self, forKey: .untilSkipping) {
            self = .until(m, skipping: s)
        } else {
            throw CodableError.unrecognizedDuration
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .timeInterval(let dc):
            try container.encode(dc, forKey: .timeInterval)
        case .until(let m, let skipping):
            try container.encode(m, forKey: .untilMoment)
            try container.encode(skipping, forKey: .untilSkipping)
        }
    }
}

extension EncounterMoment: Codable {
    enum CodingKeys: CodingKey {
        case turnStart
        case turnEnd
    }

    enum CodableError: Error {
        case unrecognizedMoment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let t = try? container.decode(Turn.self, forKey: .turnStart) {
            self = .turnStart(t)
        } else if let t = try? container.decode(Turn.self, forKey: .turnEnd) {
            self = .turnEnd(t)
        } else {
            throw CodableError.unrecognizedMoment
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .turnStart(let t):
            try container.encode(t, forKey: .turnStart)
        case .turnEnd(let t):
            try container.encode(t, forKey: .turnEnd)
        }
    }
}

extension EncounterMoment.Turn: Codable {
    enum CodingKeys: CodingKey {
        case source
        case target
        case combatant
    }

    enum CodableError: Error {
        case unrecognizedTurn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decode(String.self, forKey: .source)) == CodingKeys.source.description {
            self = .source
        } else if (try? container.decode(String.self, forKey: .target)) == CodingKeys.target.description {
            self = .target
        } else if let id = try? container.decode(Combatant.Id.self, forKey: .combatant) {
            self = .combatant(id)
        } else {
            throw CodableError.unrecognizedTurn
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .source:
            try container.encode(CodingKeys.source.description, forKey: CodingKeys.source)
        case .target:
            try container.encode(CodingKeys.target.description, forKey: CodingKeys.target)
        case .combatant(let uuid):
            try container.encode(uuid, forKey: CodingKeys.combatant)
        }
    }
}

extension EffectDuration {
    func description(environment: Environment, context: EffectContext) -> String? {
        switch self {
        case .timeInterval(let i):
            return DateComponentsFormatter().string(from: i)
        case .until(let m, _):
            guard let turnString = ordinalTurnDescription(environment: environment, context: context) else { return nil }

            switch m {
            case .turnStart(let t):
                guard let c = t.resolve(in: context),
                    let names = ListFormatter().string(from: c.map { $0.discriminatedName }) else { return nil }

                return "Start of \(names)'s \(turnString)"
            case .turnEnd(let t):
                guard let c = t.resolve(in: context),
                    let names = ListFormatter().string(from: c.map { $0.discriminatedName }) else { return nil }
                return "End of \(names)'s \(turnString)"
            }
        }
    }

    func ordinalTurnDescription(environment: Environment, context: EffectContext) -> String? {
        switch self {
        case .timeInterval:
            return nil
        case .until(let m, let skipping):
            var turns = skipping + 1
            if context.running.currentTurn(has: m, context: context) {
                turns -= 1
            }

            switch turns {
            case 0: return "current turn"
            case 1: return "next turn"
            default: return "\(environment.ordinalFormatter.stringWithFallback(for: turns)) turn"
            }
        }
    }
}

extension EncounterMoment.Turn {
    func resolve(in context: EffectContext) -> [Combatant]? {
        switch self {
        case .source:
            return context.source.map { [$0] }
        case .target:
            return context.targets
        case .combatant(let id):
            return context.combatants.first(where: { $0.id == id }).map { [$0] }
        }
    }
}

extension EffectContext {
    init(running: RunningEncounter, combatant: Combatant, tag: CombatantTag) {
        self = EffectContext(
            source: tag.sourceCombatantId.flatMap { running.current.combatants[id: $0] },
            targets: [combatant],
            running: running
        )
    }
}
