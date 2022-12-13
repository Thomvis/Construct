//
//  CreatureActionDescription.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation
import GameModels

public struct CreatureActionDescriptionRequest: Hashable {
    public let creatureName: String // e.g. "Goblin"
    public let isUniqueCreature: Bool // true for named foes (e.g. Acererak)
    public let creatureDescription: String? // e.g. "small humanoid"
    public let creatureCondition: String? // e.g. "hidden, looking rough"

    public let encounter: Encounter?

    public let actionName: String // e.g. "Shortbow"
    public let actionDescription: String // e.g. "Ranged Weapon Attack: +4 to hit, range 80/320 ft., " etc

    public var outcome: Outcome

    public init(
        creatureName: String,
        isUniqueCreature: Bool,
        creatureDescription: String?,
        creatureCondition: String?,
        encounter: Encounter?,
        actionName: String,
        actionDescription: String,
        outcome: Outcome
    ) {
        self.creatureName = creatureName
        self.isUniqueCreature = isUniqueCreature
        self.creatureDescription = creatureDescription
        self.creatureCondition = creatureCondition
        self.encounter = encounter
        self.actionName = actionName
        self.actionDescription = actionDescription
        self.outcome = outcome
    }

    public struct Encounter: Hashable {
        let name: String?
        let actionSetUp: String? // things pertaining to the encounter, action & creature happening before this action

        public init(name: String?, actionSetUp: String?) {
            self.name = name
            self.actionSetUp = actionSetUp
        }
    }

    public enum Impact: Hashable {
        case minimal
        case average
        case devastating
    }

    public enum Outcome: Hashable {
        case miss(Bool) // true if critical
        case hit(Hit)

        public var isHit: Bool {
            guard case .hit = self else { return false }
            return true
        }

        public struct Hit: Hashable {
            public var isCritical: Bool
            public var damageDescription: String // e.g. "10 piercing"
            public var attackImpact: Impact

            public init(isCritical: Bool, damageDescription: String, attackImpact: Impact) {
                self.isCritical = isCritical
                self.damageDescription = damageDescription
                self.attackImpact = attackImpact
            }
        }
    }
}

public extension CreatureActionDescriptionRequest.Outcome {
    static let averageHitDamageDescription = "average amount of damage"

    static let criticalMiss: Self = .miss(true)
    static let miss: Self = .miss(false)
    static let averageHit: Self = .hit(Hit(isCritical: false, damageDescription: averageHitDamageDescription, attackImpact: .average))
    static let criticalHit: Self = .hit(Hit(isCritical: true, damageDescription: "large amount of damage", attackImpact: .devastating))
}

extension CreatureActionDescriptionRequest: PromptConvertible {
    public func prompt(toneOfVoice: ToneOfVoice) -> String {
        let enemyNoun = isUniqueCreature ? "NPC" : "monster"

        // init result with prelude
        var result = """
        During a D&D combat encounter, a player is attacked by a \(enemyNoun).
        """

        if let encounter {
            result += """
            Encounter: \(encounter.name.wrap(suffix: ". "))\(" ".with(encounter.actionSetUp))
            """
        }

        result += """
        Attacking \(enemyNoun): \(creatureName)\(creatureDescription.wrap(prefix: " (", suffix: ")"))\(", ".with(creatureCondition)).
        """

        result += """
        The \(enemyNoun) attacks using "\(actionName)".
        """

        switch outcome {
        case .miss(true):
            result += "The attack is a critical miss. "
        case .miss(false):
            result += "The attack misses. "
        case .hit(let hit):
            let impactString: String
            switch hit.attackImpact {
            case .minimal:
                impactString = "an ineffective"
            case .average:
                impactString = "an average"
            case .devastating:
                impactString = "a devastating"
            }

            result += """
            The attack\(hit.isCritical ? " critically" : "") hits the player for \(impactString) \(hit.damageDescription).
            """
        }

        result += """
        What does the DM say to the attacked player? Describe the \(enemyNoun) and the attack, using a \(toneOfVoice) style.
        """

        if case .hit = outcome {
            result += "Mention the damage."
        }

        return result
    }
}

extension CreatureActionDescriptionRequest {
    public init(creature: CompendiumCombatant, action: CreatureAction) {
        self.creatureName = creature.stats.name
        self.isUniqueCreature = creature.isUnique
        self.creatureDescription = Self.creatureDescription(from: creature.stats)
        self.creatureCondition = nil

        self.encounter = nil

        self.actionName = action.name
        self.actionDescription = action.description

        self.outcome = .hit(.init(
            isCritical: false,
            damageDescription: "6 points of bludgeoning damage", // todo
            attackImpact: .average
        ))
    }

    public static func creatureDescription(from stats: StatBlock) -> String {
        return [
            stats.size?.localizedDisplayName,
            stats.type?.localizedDisplayName
        ].compactMap { $0 }.joined(separator: " ")
    }
}
