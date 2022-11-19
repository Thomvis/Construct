//
//  Characters.swift
//  Construct
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

public struct Character: Hashable {
    public var id: Id
    public var realm: CompendiumItemKey.Realm
    public var level: Int?
    public var stats: StatBlock
    public var player: Player?

    public init(id: Id, realm: CompendiumItemKey.Realm, level: Int? = nil, stats: StatBlock, player: Player? = nil) {
        self.id = id
        self.realm = realm
        self.level = level
        self.stats = stats
        self.player = player
    }

    public typealias Id = Tagged<Character, UUID>
}

extension Character: CompendiumItem {
    public var key: CompendiumItemKey {
        return CompendiumItemKey(type: .character, realm: realm, identifier: id.rawValue.uuidString)
    }

    public var title: String {
        return stats.name
    }
}

public extension Character {
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
                components.append(type.localizedDisplayName)
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
