//
//  Monsters.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

struct Monster: Hashable {
    var realm: CompendiumItemKey.Realm
    var stats: StatBlock
    var challengeRating: Fraction
}

extension Monster: CompendiumItem {
    var key: CompendiumItemKey {
        return CompendiumItemKey(type: .monster, realm: realm, identifier: stats.name)
    }

    var title: String {
        stats.name
    }
}

extension Monster {
    var localizedStatsSummary: String {
        [
            "CR \(challengeRating.rawValue)",
            stats.type.map { "\($0)" }
        ].compactMap { $0}.joined(separator: " | ")
    }
}
