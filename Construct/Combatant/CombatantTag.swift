//
//  CombatantTag.swift
//  Construct
//
//  Created by Thomas Visser on 21/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

struct CombatantTag: Codable, Hashable {
    let id: Id
    let definition: CombatantTagDefinition

    var note: String?

    var duration: EffectDuration?
    var addedIn: RunningEncounter.Turn?

    var sourceCombatantId: Combatant.Id?

    typealias Id = Tagged<CombatantTag, UUID>
}

struct CombatantTagDefinition: Hashable, Codable, Equatable {
    let name: String
    let category: Category
}

extension CombatantTagDefinition {
    enum Category: String, CaseIterable, Codable, Equatable {
        case tactics
        case condition
        case spells
        case other

        var title: String {
            switch self {
            case .tactics: return "Tactics"
            case .condition: return "Condition"
            case .spells: return "Spells"
            case .other: return "Other"
            }
        }
    }
}

extension CombatantTagDefinition {
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

extension CombatantTag {

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
    static let nullInstance = CombatantTag(id: UUID().tagged(), definition: CombatantTagDefinition.nullInstance, note: nil, duration: nil, addedIn: nil, sourceCombatantId: nil)
}

extension CombatantTagDefinition {
    static let nullInstance = CombatantTagDefinition(name: "", category: .other)
}
