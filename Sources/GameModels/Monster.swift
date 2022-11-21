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
        assert(self.stats.challengeRating == nil || self.stats.challengeRating == challengeRating)
        self.stats.challengeRating = challengeRating
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
        var components: [String] = [
            "CR \(challengeRating.rawValue)"
        ]

        if let type = self.stats.type {
            if let subtype = self.stats.subtype?.nonEmptyString {
                components.append("\(type.localizedDisplayName) (\(subtype.capitalized))")
            } else {
                components.append(type.localizedDisplayName)
            }
        }

        return components.joined(separator: " | ")
    }
}

public enum MonsterType: String, CaseIterable, Codable, Hashable {
    case aberation, beast, celestial, construct, dragon, elemental, fey
    case fiend, giant, humanoid, monstrosity, ooze, plant, undead

    public var localizedDisplayName: String {
        switch self {
        case .aberation: return NSLocalizedString("Aberation", comment: "Monster type aberation")
        case .beast: return NSLocalizedString("Beast", comment: "Monster type beast")
        case .celestial: return NSLocalizedString("Celestial", comment: "Monster type celestial")
        case .construct: return NSLocalizedString("Construct", comment: "Monster type construct")
        case .dragon: return NSLocalizedString("Dragon", comment: "Monster type dragon")
        case .elemental: return NSLocalizedString("Elemental", comment: "Monster type elemental")
        case .fey: return NSLocalizedString("Fey", comment: "Monster type fey")
        case .fiend: return NSLocalizedString("Fiend", comment: "Monster type fiend")
        case .giant: return NSLocalizedString("Giant", comment: "Monster type giant")
        case .humanoid: return NSLocalizedString("Humanoid", comment: "Monster type humanoid")
        case .monstrosity: return NSLocalizedString("Monstrosity", comment: "Monster type monstrosity")
        case .ooze: return NSLocalizedString("Ooze", comment: "Monster type ooze")
        case .plant: return NSLocalizedString("Plant", comment: "Monster type plant")
        case .undead: return NSLocalizedString("Undead", comment: "Monster type undead")
        }
    }
}
