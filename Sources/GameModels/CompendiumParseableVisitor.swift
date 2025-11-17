//
//  CompendiumParseableVisitor.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Helpers
import Dice

public extension ParseableMonsterType {
    mutating func parseIfNeeded() -> Bool {
        parseIfNeeded(parser: MonsterTypeDomainParser.self)
    }
}

public extension ParseableCreatureAction {
    mutating func parseIfNeeded() -> Bool {
        parseIfNeeded(parser: CreatureActionDomainParser.self)
    }
}

public extension ParseableCreatureFeature {
    @discardableResult
    mutating func parseIfNeeded() -> Bool {
        parseIfNeeded(parser: CreatureFeatureDomainParser.self)
    }
}

public extension ParseableSpellDescription {
    @discardableResult
    mutating func parseIfNeeded() -> Bool {
        parseIfNeeded(parser: SpellDescriptionDomainParser.self)
    }
}
