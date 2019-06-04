//
//  AdHocCombatant.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 27/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

public struct AdHocCombatantDefinition: Hashable, CombatantDefinition, Codable {
    public let id: UUID
    var name: String { stats?.name ?? "" }

    var ac: Int? { stats?.armorClass }
    var hitPoints: Int? { stats?.hitPoints }

    var initiativeModifier: Int? { stats?.effectiveInitiativeModifier }
    var initiativeGroupingHint: String { id.uuidString }

    var stats: StatBlock? = nil

    var player: Player?
    var level: Int?

    var original: CompendiumItemReference? // the compendium combatant this combatant is based on

    var isUnique: Bool { player != nil }

    var definitionID: String {
        return id.uuidString
    }
}

extension Combatant {
    init(adHoc definition: AdHocCombatantDefinition) {
        self.init(
            definition: definition,
            hp: definition.hitPoints.map { Hp(fullHealth: $0) }
        )
    }
}
