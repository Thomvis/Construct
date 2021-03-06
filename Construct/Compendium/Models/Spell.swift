//
//  Spell.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 12/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

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

    let description: String
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
