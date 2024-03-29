//
//  ModelsParseableVisitor.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import CasePaths
import ComposableArchitecture
import Helpers

extension Encounter: HasParseableVisitor {
    public static let parseableVisitor: ParseableVisitor<Encounter> = .combine(
        Combatant.parseableVisitor.visitEach(in: \.combatants)
    )
}

extension Combatant: HasParseableVisitor {
    public static let parseableVisitor: ParseableVisitor<Combatant> = .combine(
        AdHocCombatantDefinition.parseableVisitor.ifSome().pullback(state: \.adHocDefinition, action: CasePath.`self`),
        CompendiumCombatantDefinition.parseableVisitor.ifSome().pullback(state: \.compendiumDefinition, action: CasePath.`self`)
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
        StatBlock.parseableVisitor.pullback(state: \.stats, action: CasePath.`self`)
    )
}

extension CompendiumCombatantDefinition {
    static let parseableVisitor: ParseableVisitor<CompendiumCombatantDefinition> = .combine(
        Monster.parseableVisitor.ifSome().pullback(state: \.monster, action: CasePath.`self`),
        Character.parseableVisitor.ifSome().pullback(state: \.character, action: CasePath.`self`)
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

extension RunningEncounter: HasParseableVisitor {
    public static let parseableVisitor: ParseableVisitor<RunningEncounter> = .combine(
        Encounter.parseableVisitor.pullback(state: \.base, action: CasePath.`self`),
        Encounter.parseableVisitor.pullback(state: \.current, action: CasePath.`self`)
    )
}
