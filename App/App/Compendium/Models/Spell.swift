//
//  Spell.swift
//  Construct
//
//  Created by Thomas Visser on 12/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels

struct Spell: Codable {
    var realm: CompendiumItemKey.Realm
    var name: String

    let level: Int? // nil for cantrip
    let castingTime: String
    let range: String
    let components: [Component]
    let ritual: Bool
    let duration: String
    let school: String
    let concentration: Bool

    var description: ParseableSpellDescription
    let higherLevelDescription: String?

    let classes: [String]
    let material: String?


    enum Component: String, Codable {
        case verbal, somatic, material
    }

}

extension Spell: CompendiumItem, Equatable {
    var key: CompendiumItemKey {
        return CompendiumItemKey(type: .spell, realm: realm, identifier: name)
    }

    var title: String {
        return name
    }
}

extension Spell.Component {
    init?(abbreviation: String) {
        switch abbreviation {
        case "V": self = .verbal
        case "S": self = .somatic
        case "M": self = .material
        default: return nil
        }
    }
}
