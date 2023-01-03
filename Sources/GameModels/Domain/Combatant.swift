//
//  Combatant.swift
//  Construct
//
//  Created by Thomas Visser on 27/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Combine
import Tagged
import Helpers

public struct Combatant: Equatable, Codable, Identifiable {
    public let id: Id
    public var discriminator: Int? = nil

    private var _definition: CodableCombatDefinition
    public var definition: CombatantDefinition {
        get { _definition.definition }
        set { _definition.definition = newValue }
    }

    var _hp: Hp?
    public var hp: Hp? {
        get { _hp ?? definition.hitPoints.map(Hp.init) }
        set { _hp = newValue }
    }
    public var resources: IdentifiedArray<CombatantResource.Id, CombatantResource>

    public var initiative: Int?
    public var tags: [CombatantTag] = []

    public var characteristics: Characteristics?

    public var party: CompendiumItemReference?

    public init(discriminator: Int? = nil, definition: CombatantDefinition, hp: Hp? = nil, resources: [CombatantResource] = [], initiative: Int? = nil, party: CompendiumItemReference? = nil) {
        self.id = UUID().tagged()
        self.discriminator = discriminator
        self._definition = CodableCombatDefinition(definition: definition)
        self._hp = hp
        self.resources = IdentifiedArray(uniqueElements: resources)
        self.initiative = initiative
        self.party = party
    }

    public typealias Id = Tagged<Combatant, UUID>

    public struct CodableCombatDefinition: Equatable {
        @EqCompare public var definition: CombatantDefinition

        public init(definition: CombatantDefinition) {
            _definition = EqCompare(wrappedValue: definition, compare: { $0.isEqual(to: $1) })
        }
    }
}

public extension Combatant {
    var name: String {
        return definition.name
    }

    var discriminatedName: String {
        if let discriminator = discriminator {
            return "\(name) \(discriminator)"
        }
        return name
    }

    var isDead: Bool {
        guard let hp = hp else { return false }
        return hp.effective <= 0
    }
}

public protocol CombatantDefinition {
    var definitionID: String { get }

    var name: String { get }
    var ac: Int? { get }
    var hitPoints: Int? { get }

    var initiativeModifier: Int? { get }
    var initiativeGroupingHint: String { get }

    var stats: StatBlock { get set }

    var player: Player? { get }
    var level: Int? { get }

    var isUnique: Bool { get }

    func isEqual(to other: CombatantDefinition) -> Bool

}

extension CombatantDefinition where Self: Equatable {
    public func isEqual(to other: CombatantDefinition) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}

public struct Hp: Codable, Hashable {
    public var current: Int
    public var maximum: Int
    public var temporary: Int

    public var effective: Int {
        return max(0, current + temporary)
    }

    // Goes below zero
    public var unboundedEffective: Int {
        current + temporary
    }

    // negative values are ignored
    public mutating func heal(_ v: Int) {
        current = min(max(0, current) + v, maximum)
    }

    public mutating func hit(_ v: Int) {
        // remove temporary hit points first
        let t = temporary
        temporary = max(0, t - v)

        // overflow to current
        if v - t > 0 {
            current -= (v-t)
        }
    }

    // A positive value heals, a negative value hits
    public mutating func apply(_ v: Int) {
        if v > 0 {
            heal(v)
        } else {
            hit(-v)
        }
    }
}

extension Hp {
    public init(fullHealth hp: Int) {
        self.current = hp
        self.maximum = hp
        self.temporary = 0
    }
}

public extension Hp {
    var accessibilityText: String {
        var result = "HP: \(effective) of \(maximum)"
        if temporary > 0 {
            result.append(" including \(temporary) temporary")
        }
        return result
    }
}

public struct Player: Codable, Hashable {
    public var name: String?

    public init(name: String? = nil) {
        self.name = name
    }
}

extension Combatant.CodableCombatDefinition: Codable {
    enum CodableError: Error {
        case unrecognizedCombatantDefinition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let adHoc = try? container.decode(AdHocCombatantDefinition.self) {
            self.init(definition: adHoc)
        } else if let compendium = try? container.decode(CompendiumCombatantDefinition.self) {
            self.init(definition: compendium)
        } else {
            throw CodableError.unrecognizedCombatantDefinition
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch definition {
        case let d as AdHocCombatantDefinition:
            try container.encode(d)
        case let d as CompendiumCombatantDefinition:
            try container.encode(d)
        default:
            throw CodableError.unrecognizedCombatantDefinition
        }

    }
}

public struct CombatantResource: Codable, Hashable, Identifiable {
    public let id: Id
    public var title: String
    public var slots: [Bool] // false if available, true if used

    public init(id: Id, title: String, slots: [Bool]) {
        self.id = id
        self.title = title
        self.slots = slots
    }

    public mutating func reset() {
        slots = Array(repeating: false, count: slots.count)
    }

    public var used: Int {
        get {
            slots.filter { $0 }.count
        }
        set {
            for i in slots.indices {
                if i < newValue {
                    slots[i] = true
                } else {
                    slots[i] = false
                }
            }
        }
    }

    public var remaining: Int {
        slots.filter { !$0 }.count
    }

    public typealias Id = Tagged<CombatantResource, UUID>
}

public extension CombatantResource {

    /**
     Initializes a resource with available slots
     */
    init(id: Id = UUID().tagged(), title: String, slotCount: Int) {
        self.id = id
        self.title = title
        self.slots = Array(repeating: false, count: slotCount)
    }
    
}

extension Combatant {
    /// Things that
    public struct Characteristics: Codable, Equatable {
        public var appearance: String?
        public var behavior: String?
        public var nickname: String?
        public var generatedByMechMuse: Bool

        public init(appearance: String?, behavior: String?, nickname: String?, generatedByMechMuse: Bool) {
            self.appearance = appearance
            self.behavior = behavior
            self.nickname = nickname
            self.generatedByMechMuse = generatedByMechMuse
        }
    }

    public var hasCharacteristics: Bool {
        characteristics?.appearance != nil || characteristics?.behavior != nil || characteristics?.nickname != nil
    }
}

public extension StatBlock {
    var effectiveInitiativeModifier: Int? {
        initiative?.modifier.modifier ?? abilityScores?.dexterity.modifier.modifier
    }
}

public extension Combatant {
    static let nullInstance = Combatant(adHoc: AdHocCombatantDefinition(id: UUID().tagged(), stats: StatBlock.default))
}

public extension CombatantResource {
    static let nullInstance = CombatantResource(id: UUID().tagged(), title: "", slots: [])
}
