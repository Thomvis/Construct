//
//  CompendiumParseableVisitor.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import CasePaths

extension CompendiumEntry: HasParseableVisitor {
    static let parseableVisitor: ParseableVisitor<CompendiumEntry> = .combine(
        Monster.parseableVisitor.ifSome().pullback(state: \.monster, action: CasePath.`self`),
        Character.parseableVisitor.ifSome().pullback(state: \.character, action: CasePath.`self`),
        Spell.parseableVisitor.ifSome().pullback(state: \.spell, action: CasePath.`self`)
    )

    var monster: Monster? {
        get {
            item as? Monster
        }
        set {
            if let newValue = newValue {
                item = newValue
            }
        }
    }

    var character: Character? {
        get {
            item as? Character
        }
        set {
            if let newValue = newValue {
                item = newValue
            }
        }
    }

    var spell: Spell? {
        get {
            item as? Spell
        }
        set {
            if let newValue = newValue {
                item = newValue
            }
        }
    }
}

extension Monster {
    static let parseableVisitor: ParseableVisitor<Monster> = .combine(
        StatBlock.parseableVisitor.pullback(state: \.stats, action: CasePath.`self`)
    )
}

extension Character {
    static let parseableVisitor: ParseableVisitor<Character> = .combine(
        StatBlock.parseableVisitor.pullback(state: \.stats, action: CasePath.`self`)
    )
}

extension Spell {
    static let parseableVisitor: ParseableVisitor<Spell> = ParseableVisitor { spell in
        spell.description.parseIfNeeded()
    }
}

extension StatBlock {
    static let parseableVisitor: ParseableVisitor<StatBlock> = ParseableVisitor { statBlock in
        for i in statBlock.features.indices {
            statBlock.features[i].parseIfNeeded()
        }

        for i in statBlock.actions.indices {
            statBlock.actions[i].parseIfNeeded()
        }

        for i in statBlock.reactions.indices {
            statBlock.reactions[i].parseIfNeeded()
        }

        for i in (statBlock.legendary?.actions.indices ?? [].indices) {
            statBlock.legendary?.actions[i].parseIfNeeded()
        }
    }
}
