//
//  CombatantTag.swift
//  Construct
//
//  Created by Thomas Visser on 21/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

public struct CombatantTag: Codable, Hashable {
    public let id: Id
    public let definition: CombatantTagDefinition

    public var note: String?

    public var duration: EffectDuration?
    public var addedIn: RunningEncounter.Turn?

    public var sourceCombatantId: Combatant.Id?

    public init(
        id: Id,
        definition: CombatantTagDefinition,
        note: String? = nil,
        duration: EffectDuration? = nil,
        addedIn: RunningEncounter.Turn? = nil,
        sourceCombatantId: Combatant.Id? = nil
    ) {
        self.id = id
        self.definition = definition
        self.note = note
        self.duration = duration
        self.addedIn = addedIn
        self.sourceCombatantId = sourceCombatantId
    }

    public typealias Id = Tagged<CombatantTag, UUID>
}

public struct CombatantTagDefinition: Hashable, Codable, Equatable {
    public let name: String
    public let category: Category
}

public extension CombatantTagDefinition {
    enum Category: String, CaseIterable, Codable, Equatable {
        case tactics
        case condition
        case spells
        case other

        public var title: String {
            switch self {
            case .tactics: return "Tactics"
            case .condition: return "Condition"
            case .spells: return "Spells"
            case .other: return "Other"
            }
        }
    }
}

public extension CombatantTagDefinition {
    static let all: [CombatantTagDefinition] = [
        // Tactics
        CombatantTagDefinition(name: "Hidden", category: .tactics),
        CombatantTagDefinition(name: "Half Cover", category: .tactics),
        CombatantTagDefinition(name: "Three-Quarters Cover", category: .tactics),
        CombatantTagDefinition(name: "Full Cover", category: .tactics),

        // Condition
        CombatantTagDefinition(name: "Blinded", category: .condition),
        CombatantTagDefinition(name: "Charmed", category: .condition),
        CombatantTagDefinition(name: "Deafened", category: .condition),
        CombatantTagDefinition(name: "Fatigued", category: .condition),
        CombatantTagDefinition(name: "Frightened", category: .condition),
        CombatantTagDefinition(name: "Grappled", category: .condition),
        CombatantTagDefinition(name: "Incapacitated", category: .condition),
        CombatantTagDefinition(name: "Invisible", category: .condition),
        CombatantTagDefinition(name: "Paralyzed", category: .condition),
        CombatantTagDefinition(name: "Petrified", category: .condition),
        CombatantTagDefinition(name: "Poisoned", category: .condition),
        CombatantTagDefinition(name: "Prone", category: .condition),
        CombatantTagDefinition(name: "Restrained", category: .condition),
        CombatantTagDefinition(name: "Stunned", category: .condition),
        CombatantTagDefinition(name: "Unconscious", category: .condition),

        // Spells
        CombatantTagDefinition(name: "Blessed", category: .spells),
        CombatantTagDefinition(name: "Enlarged", category: .spells),
        CombatantTagDefinition(name: "Faerie Fire", category: .spells),
        CombatantTagDefinition(name: "Hasted", category: .spells),
        CombatantTagDefinition(name: "Hexed", category: .spells),
        CombatantTagDefinition(name: "Reduced", category: .spells),
        CombatantTagDefinition(name: "Silenced", category: .spells),
        CombatantTagDefinition(name: "Slowed", category: .spells),

        // Other
        CombatantTagDefinition(name: "Concentrating", category: .other),
        CombatantTagDefinition(name: "Surprised", category: .other),
        CombatantTagDefinition(name: "Disadvantage on next attack", category: .other),
    ]

    static func all(in category: Category) -> [CombatantTagDefinition] {
        all.filter { $0.category == category }
    }
}

public extension CombatantTag {

    // Combines note and definition name if the note is short
    var title: String {
        if let note = note, hasInlineNote { // "DC XX" fits
            return "\(definition.name) (\(note))"
        }
        return definition.name
    }

    var hasInlineNote: Bool {
        note.map { $0.count < 6 } ?? false
    }

    var hasLongNote: Bool {
        note != nil && !hasInlineNote
    }
}

extension CombatantTag: Identifiable {

}

extension CombatantTag {
    public static let nullInstance = CombatantTag(id: UUID().tagged(), definition: CombatantTagDefinition.nullInstance, note: nil, duration: nil, addedIn: nil, sourceCombatantId: nil)
}

extension CombatantTagDefinition {
    public static let nullInstance = CombatantTagDefinition(name: "", category: .other)
}
