//
//  Monsters.swift
//  Construct
//
//  Created by Thomas Visser on 26/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

public struct Monster: Hashable {
    public var realm: CompendiumItemKey.Realm
    public var stats: StatBlock
    public var challengeRating: Fraction

    public init(realm: CompendiumItemKey.Realm, stats: StatBlock, challengeRating: Fraction) {
        self.realm = realm
        self.stats = stats
        self.challengeRating = challengeRating
    }
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

public enum MonsterType: String, CaseIterable, Codable, Hashable {
    case abberation, beast, celestial, construct, dragon, elemental, fey
    case fiend, giant, humanoid, ooze, plant, undead

    public var localizedDisplayName: String {
        switch self {
        case .abberation: return NSLocalizedString("Abberation", comment: "Monster type abberation")
        case .beast: return NSLocalizedString("Beast", comment: "Monster type beast")
        case .celestial: return NSLocalizedString("Celestial", comment: "Monster type celestial")
        case .construct: return NSLocalizedString("Construct", comment: "Monster type construct")
        case .dragon: return NSLocalizedString("Dragon", comment: "Monster type dragon")
        case .elemental: return NSLocalizedString("Elemental", comment: "Monster type elemental")
        case .fey: return NSLocalizedString("Fey", comment: "Monster type fey")
        case .fiend: return NSLocalizedString("Fiend", comment: "Monster type fiend")
        case .giant: return NSLocalizedString("Giant", comment: "Monster type giant")
        case .humanoid: return NSLocalizedString("Humanoid", comment: "Monster type humanoid")
        case .ooze: return NSLocalizedString("Ooze", comment: "Monster type ooze")
        case .plant: return NSLocalizedString("Plant", comment: "Monster type plant")
        case .undead: return NSLocalizedString("Undead", comment: "Monster type undead")
        }
    }
}
