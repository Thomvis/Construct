//
//  CompendiumItemType.swift
//  
//
//  Created by Thomas Visser on 19/08/2022.
//

import Foundation

public enum CompendiumItemType: String, CaseIterable, Codable, Identifiable {
    case monster
    case character
    case spell
    case group

    public var id: String {
        rawValue
    }

    public var localizedDisplayName: String {
        switch self {
        case .monster: return NSLocalizedString("monster", comment: "Compendium item type monster")
        case .character: return NSLocalizedString("character", comment: "Compendium item type character")
        case .spell: return NSLocalizedString("spell", comment: "Compendium item type spell")
        case .group: return NSLocalizedString("group", comment: "Compendium item type group")
        }
    }

    public var localizedScreenDisplayName: String {
        switch self {
        case .monster: return NSLocalizedString("Monsters", comment: "Compendium item type monster")
        case .character: return NSLocalizedString("Characters", comment: "Compendium item type character")
        case .spell: return NSLocalizedString("Spells", comment: "Compendium item type spell")
        case .group: return NSLocalizedString("Adventuring Parties", comment: "Compendium item type group")
        }
    }
}
