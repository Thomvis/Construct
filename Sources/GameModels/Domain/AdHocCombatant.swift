//
//  AdHocCombatant.swift
//  Construct
//
//  Created by Thomas Visser on 27/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

public struct AdHocCombatantDefinition: Hashable, CombatantDefinition, Codable {
    public let id: Id
    public var name: String { stats?.name ?? "" }

    public var ac: Int? { stats?.armorClass }
    public var hitPoints: Int? { stats?.hitPoints }

    public var initiativeModifier: Int? { stats?.effectiveInitiativeModifier }
    public var initiativeGroupingHint: String { id.rawValue.uuidString }

    public var stats: StatBlock? = nil

    public var player: Player?
    public var level: Int?

    public var original: CompendiumItemReference? // the compendium combatant this combatant is based on

    public var isUnique: Bool { player != nil }

    public var definitionID: String {
        return id.rawValue.uuidString
    }

    public init(id: Id, stats: StatBlock? = nil, player: Player? = nil, level: Int? = nil, original: CompendiumItemReference? = nil) {
        self.id = id
        self.stats = stats
        self.player = player
        self.level = level
        self.original = original
    }

    public typealias Id = Tagged<AdHocCombatantDefinition, UUID>
}

public extension Combatant {
    init(adHoc definition: AdHocCombatantDefinition) {
        self.init(
            definition: definition,
            hp: definition.hitPoints.map { Hp(fullHealth: $0) }
        )
    }
}
