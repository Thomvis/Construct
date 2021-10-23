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

struct Combatant: Equatable, Codable, Identifiable {
    let id: Id
    var discriminator: Int? = nil

    private var _definition: CodableCombatDefinition
    var definition: CombatantDefinition {
        get { _definition.definition }
        set { _definition.definition = newValue }
    }

    var _hp: Hp?
    var hp: Hp? {
        get { _hp ?? definition.hitPoints.map(Hp.init) }
        set { _hp = newValue }
    }
    var resources: IdentifiedArray<CombatantResource.Id, CombatantResource>

    var initiative: Int?
    var tags: [CombatantTag] = []

    var party: CompendiumItemReference?

    init(discriminator: Int? = nil, definition: CombatantDefinition, hp: Hp? = nil, resources: [CombatantResource] = [], initiative: Int? = nil, party: CompendiumItemReference? = nil) {
        self.id = UUID().tagged()
        self.discriminator = discriminator
        self._definition = CodableCombatDefinition(definition: definition)
        self._hp = hp
        self.resources = IdentifiedArray(uniqueElements: resources)
        self.initiative = initiative
        self.party = party
    }

    typealias Id = Tagged<Combatant, UUID>

    struct CodableCombatDefinition: Equatable {
        @EqCompare var definition: CombatantDefinition

        init(definition: CombatantDefinition) {
            _definition = EqCompare(wrappedValue: definition, compare: { $0.isEqual(to: $1) })
        }
    }
}

extension Combatant {
    var name: String {
        return definition.name
    }

    var isDead: Bool {
        guard let hp = hp else { return false }
        return hp.effective <= 0
    }
}

protocol CombatantDefinition {
    var definitionID: String { get }

    var name: String { get }
    var ac: Int? { get }
    var hitPoints: Int? { get }

    var initiativeModifier: Int? { get }
    var initiativeGroupingHint: String { get }

    var stats: StatBlock? { get }

    var player: Player? { get }
    var level: Int? { get }

    var isUnique: Bool { get }

    func isEqual(to other: CombatantDefinition) -> Bool

}

extension CombatantDefinition where Self: Equatable {
    func isEqual(to other: CombatantDefinition) -> Bool {
        if let other = other as? Self {
            return self == other
        }
        return false
    }
}

struct Hp: Codable, Hashable {
    var current: Int
    var maximum: Int
    var temporary: Int

    var effective: Int {
        return max(0, current + temporary)
    }

    // Goes below zero
    var unboundedEffective: Int {
        current + temporary
    }

    // negative values are ignored
    mutating func heal(_ v: Int) {
        current = min(max(0, current) + v, maximum)
    }

    mutating func hit(_ v: Int) {
        // remove temporary hit points first
        let t = temporary
        temporary = max(0, t - v)

        // overflow to current
        if v - t > 0 {
            current -= (v-t)
        }
    }

    // A positive value heals, a negative value hits
    mutating func apply(_ v: Int) {
        if v > 0 {
            heal(v)
        } else {
            hit(-v)
        }
    }
}

extension Hp {
    init(fullHealth hp: Int) {
        self.current = hp
        self.maximum = hp
        self.temporary = 0
    }

    enum Action: Equatable {
        case current(ModifyIntAction)
        case maximum(ModifyIntAction)
        case temporary(ModifyIntAction)
        case reset
    }

    enum ModifyIntAction: Equatable {
        case add(Int)
        case set(Int)
    }

    static let reducer: Reducer<Hp, Action, Environment> = Reducer { state, action, _ in
        switch action {
        case .current(let m):
            switch m {
            case .add(let p): state.apply(p)
            case .set(let p): state.current = p
            }
        case .maximum(let m):
            switch m {
            case .add(let p):
                state.maximum += p
                state.apply(0)
            case .set(let p):
                state.maximum = p
                state.apply(0)
            }
        case .temporary(let m):
            switch m {
            case .add(let p): state.temporary += p
            case .set(let p): state.temporary = p
            }
        case .reset:
            state.current = state.maximum
            state.temporary = 0
        }
        return .none
    }
}

extension Hp {
    var accessibilityText: String {
        var result = "HP: \(effective) of \(maximum)"
        if temporary > 0 {
            result.append(" including \(temporary) temporary")
        }
        return result
    }
}

struct Player: Codable, Hashable {
    var name: String?
}

extension Combatant.CodableCombatDefinition: Codable {
    enum CodableError: Error {
        case unrecognizedCombatantDefinition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let adHoc = try? container.decode(AdHocCombatantDefinition.self) {
            self.init(definition: adHoc)
        } else if let compendium = try? container.decode(CompendiumCombatantDefinition.self) {
            self.init(definition: compendium)
        } else {
            throw CodableError.unrecognizedCombatantDefinition
        }
    }

    func encode(to encoder: Encoder) throws {
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

struct CombatantResource: Codable, Hashable, Identifiable {
    let id: Id
    var title: String
    var slots: [Bool] // false if available, true if used

    mutating func reset() {
        slots = Array(repeating: false, count: slots.count)
    }

    var used: Int {
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

    var remaining: Int {
        slots.filter { !$0 }.count
    }

    typealias Id = Tagged<CombatantResource, UUID>
}

enum CombatantAction: Equatable {
    case hp(Hp.Action)
    case initiative(Int)
    case resource(CombatantResource.Id, CombatantResourceAction)
    case addResource(CombatantResource)
    case removeResource(CombatantResource)
    case addTag(CombatantTag)
    case removeTag(CombatantTag)
    case reset(hp: Bool, initiative: Bool, resources: Bool, tags: Bool)
    case setDefinition(Combatant.CodableCombatDefinition)

    var hp: Hp.Action? {
        get {
            guard case .hp(let a) = self else { return nil }
            return a
        }
        set {
            guard case .hp = self, let value = newValue else { return }
            self = .hp(value)
        }
    }
}

let combatantReducer: Reducer<Combatant, CombatantAction, Environment> = Reducer.combine(
Reducer { state, action, _ in
    switch action {
    case .initiative(let score): state.initiative = score
    case .addResource(let r): state.resources.append(r)
    case .removeResource(let r): state.resources.removeAll { $0.id == r.id }
    case .addTag(let t): state.tags[id: t.id] = t
    case .removeTag(let t): state.tags.removeAll { $0.id == t.id }
    case .hp, .resource: break
    case .reset(let hp, let initiative, let resources, let tags):
        if initiative { state.initiative = nil }
        if tags { state.tags.removeAll() }

        return Effect.run { [state] subscriber in
            if resources {
                for r in state.resources {
                    subscriber.send(CombatantAction.resource(r.id, .reset))
                }
            }

            if hp {
                subscriber.send(.hp(.reset))
            }

            subscriber.send(completion: .finished)
            return AnyCancellable { }
        }
    case .setDefinition(let def):
        if state.definition.definitionID != def.definition.definitionID {
            state.discriminator = nil
        }
        state.definition = def.definition
    }
    return .none
},
Hp.reducer.optional().pullback(state: \.hp, action: /CombatantAction.hp, environment: { $0 }),
CombatantResource.reducer.forEach(state: \.resources, action: /CombatantAction.resource, environment: { $0 })
)

enum CombatantResourceAction: Equatable {
    case title(String)
    case reset
    case slot(Int, Bool)
}

extension CombatantResource {
    static let reducer: Reducer<CombatantResource, CombatantResourceAction, Environment> = Reducer { state, action, _ in
        switch action {
        case .title(let t):
            state.title = t
        case .reset:
            state.reset()
        case .slot(let idx, let v):
            state.slots[idx] = v
        }
        return .none
    }
}

extension StatBlock {
    var effectiveInitiativeModifier: Int? {
        initiative?.modifier.modifier ?? abilityScores?.dexterity.modifier.modifier
    }
}

extension Combatant {
    static let nullInstance = Combatant(adHoc: AdHocCombatantDefinition(id: UUID().tagged()))
}

extension CombatantResource {
    static let nullInstance = CombatantResource(id: UUID().tagged(), title: "", slots: [])
}
