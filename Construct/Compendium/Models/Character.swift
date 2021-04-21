//
//  Characters.swift
//  Construct
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

struct Character: Hashable {
    var id: Id
    var realm: CompendiumItemKey.Realm
    var level: Int?
    var stats: StatBlock
    var player: Player?

    typealias Id = Tagged<Character, UUID>
}

extension Character: CompendiumItem {
    var key: CompendiumItemKey {
        return CompendiumItemKey(type: .character, realm: realm, identifier: id.rawValue.uuidString)
    }

    var title: String {
        return stats.name
    }
}

extension Character {
    var localizedSummary: String {
        var components: [String] = []
        if let level = self.level {
            if let type = self.stats.type {
                components.append("Level \(level) \(type)")
            } else {
                components.append("Level \(level)")
            }
        }

        if let type = self.stats.type {
            if let subtype = self.stats.subtype?.nonEmptyString {
                components.append("\(subtype) \(type)")
            } else {
                components.append(type)
            }
        }

        if let player = self.player {
            if let name = player.name {
                components.append("Played by \(name)")
            } else {
                components.append("Player character")
            }
        } else {
            components.append("NPC")
        }

        return components.joined(separator: " | ")
    }
}
