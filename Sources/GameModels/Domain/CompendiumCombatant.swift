//
//  CompendiumCombatant.swift
//  Construct
//
//  Created by Thomas Visser on 27/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

public struct CompendiumCombatantDefinition: CombatantDefinition, Codable, Equatable {
    var _item: CodableCompendiumCombatant
    public var item: CompendiumCombatant {
        get { _item.item }
        set { _item.item = newValue }
    }

    public var persistent: Bool

    public var name: String { return item.stats.name }

    public var ac: Int? { return item.stats.armorClass }
    public var hitPoints: Int? { return item.stats.hitPoints }

    public var initiativeModifier: Int? { item.stats.effectiveInitiativeModifier }
    public var initiativeGroupingHint: String { return item.key.keyString }

    public var stats: StatBlock {
        get { item.stats }
        set {
            item.stats = newValue
        }
    }

    public var player: Player? { return item.player }
    public var level: Int? { return (item as? Character)?.level }

    public var isUnique: Bool { item.isUnique }

    public init(item: CompendiumCombatant, persistent: Bool) {
        self._item = CodableCompendiumCombatant(item: item)
        self.persistent = persistent
    }

    public var definitionID: String { Self.definitionID(for: item.key) }

    public static func definitionID(for combatant: CompendiumCombatant) -> String {
        Self.definitionID(for: combatant.key)
    }

    public static func definitionID(for key: CompendiumItemKey) -> String {
        key.keyString
    }
}

public protocol CompendiumCombatant: CompendiumItem {
    var stats: StatBlock { get set }
    var player: Player? { get }

    var isUnique: Bool { get }

    func isEqual(to other: CompendiumCombatant) -> Bool
}

extension CompendiumCombatant where Self: Equatable {
    public func isEqual(to other: CompendiumCombatant) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}

extension Monster: CompendiumCombatant {
    public var player: Player? { return nil }

    public var isUnique: Bool { return false }
}

extension Character: CompendiumCombatant {
    public var isUnique: Bool { return true }
}

extension Combatant {

    public init(id: Id = UUID().tagged(), monster: Monster, hp: Hp? = nil) {
        self.init(
            id: id,
            definition: CompendiumCombatantDefinition(item: monster, persistent: false),
            hp: hp,
            resources: monster.stats.extractResources()
        )
    }

    public init(compendiumCombatant: CompendiumCombatant, hp: Hp? = nil, party: CompendiumItemReference? = nil, persistent: Bool = false) {
        self.init(
            definition: CompendiumCombatantDefinition(item: compendiumCombatant, persistent: persistent),
            hp: hp,
            resources: compendiumCombatant.stats.extractResources(),
            party: party
        )
    }
}

struct CodableCompendiumCombatant: Codable, Equatable {
    @EqCompare var item: CompendiumCombatant

    init(item: CompendiumCombatant) {
        _item = EqCompare(wrappedValue: item, compare: { $0.isEqual(to: $1) })
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let monster = try? container.decode(Monster.self) {
            self.init(item: monster)
        } else if let character = try? container.decode(Character.self) {
            self.init(item: character)
        } else {
            throw CodableError.unrecognizedCompendiumCombatant
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch item {
        case let i as Monster:
            try container.encode(i)
        case let i as Character:
            try container.encode(i)
        default:
            throw CodableError.unrecognizedCompendiumCombatant
        }
    }

    enum CodableError: Error {
        case unrecognizedCompendiumCombatant
    }
}
