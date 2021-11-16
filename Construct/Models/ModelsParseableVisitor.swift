//
//  ModelsParseableVisitor.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import CasePaths

extension Encounter: HasParseableVisitor2 {
    static let parseableVisitor: ParseableVisitor<Encounter> = .combine(
        Combatant.parseableVisitor.forEach(state: \.combatants, action: /ParseableVisitorAction.indexedVisit, environment: { })
    )
}

extension Combatant {
    static let parseableVisitor: ParseableVisitor<Combatant> = .combine(
        AdHocCombatantDefinition.parseableVisitor.optional(breakpointOnNil: false).pullback(state: \.adHocDefinition, action: CasePath.`self`)
    )

    var adHocDefinition: AdHocCombatantDefinition? {
        get {
            definition as? AdHocCombatantDefinition
        }
        set {
            if let newValue = newValue {
                definition = newValue
            }
        }
    }

    var compendiumDefinition: CompendiumCombatantDefinition? {
        get {
            definition as? CompendiumCombatantDefinition
        }
        set {
            if let newValue = newValue {
                definition = newValue
            }
        }
    }
}

extension AdHocCombatantDefinition {
    static let parseableVisitor: ParseableVisitor<AdHocCombatantDefinition> = .combine(
        StatBlock.parseableVisitor.optional(breakpointOnNil: false).pullback(state: \.stats, action: CasePath.`self`)
    )
}

extension CompendiumCombatantDefinition {
    static let parseableVisitor: ParseableVisitor<CompendiumCombatantDefinition> = .combine(
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

extension RunningEncounter: HasParseableVisitor2 {
    static let parseableVisitor: ParseableVisitor<RunningEncounter> = .combine(
        Encounter.parseableVisitor.pullback(state: \.base, action: CasePath.`self`),
        Encounter.parseableVisitor.pullback(state: \.current, action: CasePath.`self`)
    )
}
