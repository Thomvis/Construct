//
//  CompendiumParseableVisitor.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import CasePaths

extension CompendiumEntry: HasParseableVisitor2 {
    static let parseableVisitor: ParseableVisitor<CompendiumEntry> = .combine(
        Monster.parseableVisitor.optional(breakpointOnNil: false).pullback(state: \.monster, action: CasePath.`self`),
        Character.parseableVisitor.optional(breakpointOnNil: false).pullback(state: \.character, action: CasePath.`self`)
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

extension StatBlock {
    static let parseableVisitor: ParseableVisitor<StatBlock> = ParseableVisitor { statBlock in
        for i in statBlock.features.indices {
            statBlock.features[i].parseIfNeeded()
        }
    }
}
