//
//  Spell.swift
//  Construct
//
//  Created by Thomas Visser on 12/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

public struct Spell: Codable {
    public var realm: CompendiumItemKey.Realm
    public var name: String

    public let level: Int? // nil for cantrip
    public let castingTime: String
    public let range: String
    public let components: [Component]
    public let ritual: Bool
    public let duration: String
    public let school: String
    public let concentration: Bool

    public var description: ParseableSpellDescription
    public let higherLevelDescription: String?

    public let classes: [String]
    public let material: String?

    public init(realm: CompendiumItemKey.Realm, name: String, level: Int?, castingTime: String, range: String, components: [Component], ritual: Bool, duration: String, school: String, concentration: Bool, description: ParseableSpellDescription, higherLevelDescription: String?, classes: [String], material: String?) {
        self.realm = realm
        self.name = name
        self.level = level
        self.castingTime = castingTime
        self.range = range
        self.components = components
        self.ritual = ritual
        self.duration = duration
        self.school = school
        self.concentration = concentration
        self.description = description
        self.higherLevelDescription = higherLevelDescription
        self.classes = classes
        self.material = material
    }

    public enum Component: String, Codable {
        case verbal, somatic, material
    }

}

extension Spell: CompendiumItem, Equatable {
    public var key: CompendiumItemKey {
        get {
            return CompendiumItemKey(type: .spell, realm: realm, identifier: name)
        }
        set {
            assert(newValue.type == .spell)
            self.realm = newValue.realm
            self.name = newValue.identifier
        }
    }

    public var title: String {
        return name
    }
}

extension Spell.Component {
    public init?(abbreviation: String) {
        switch abbreviation {
        case "V": self = .verbal
        case "S": self = .somatic
        case "M": self = .material
        default: return nil
        }
    }
}
