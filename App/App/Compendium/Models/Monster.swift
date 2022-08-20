//
//  Monsters.swift
//  Construct
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels
import Helpers

public struct Monster: Hashable {
    public var realm: CompendiumItemKey.Realm
    public var stats: StatBlock
    public var challengeRating: Fraction
}

extension Monster: CompendiumItem {
    public var key: CompendiumItemKey {
        return CompendiumItemKey(type: .monster, realm: realm, identifier: stats.name)
    }

    public var title: String {
        stats.name
    }
}

extension Monster {
    public var localizedStatsSummary: String {
        [
            "CR \(challengeRating.rawValue)",
            stats.type.map { "\($0)" }
        ].compactMap { $0}.joined(separator: " | ")
    }
}
