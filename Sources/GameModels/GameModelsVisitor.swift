//
//  GameModelsVisitor.swift
//
//
//  Created by Thomas Visser on 13/12/2023.
//

import Foundation
import Helpers

/// Methods return true if the visitor made a change
public protocol GameModelsVisitor {
    func visit(encounter: inout Encounter) -> Bool
    func visit(runningEncounter: inout RunningEncounter) -> Bool
    func visit(entry: inout CompendiumEntry) -> Bool
    func visit(job: inout CompendiumImportJob) -> Bool
}

open class AbstractGameModelsVisitor: GameModelsVisitor {

    public init() { }

    open func visit(encounter: inout Encounter) -> Bool {
        return visitEach(
            model: &encounter,
            toCollection: \.combatants,
            visit: visit(combatant:)
        )
    }

    @VisitorBuilder
    open func visit(runningEncounter: inout RunningEncounter) -> Bool {
        visit(encounter: &runningEncounter.base)
        visit(encounter: &runningEncounter.current)
    }

    open func visit(entry: inout CompendiumEntry) -> Bool {
        var result = false

        // item
        switch entry.item {
        case var monster as Monster:
            result = visit(monster: &monster) || result
            entry.item = monster
        case var character as Character:
            result = visit(character: &character) || result
            entry.item = character
        case var spell as Spell:
            result = visit(spell: &spell) || result
            entry.item = spell
        case var group as CompendiumItemGroup:
            result = visit(group: &group) || result
            entry.item = group
        default:
            assertionFailure("Unexpected CompendiumItem in visitor")
        }

        // origin
        if case .created(var ref?) = entry.origin {
            result = visit(itemReference: &ref) || result
            entry.origin = .created(ref)
        }

        return result
    }

    open func visit(combatant: inout Combatant) -> Bool {
        var result = false
        switch combatant.definition {
        case var adHoc as AdHocCombatantDefinition:
            result = visit(adHocCombatantDefinition: &adHoc) || result
            combatant.definition = adHoc
        case var comp as CompendiumCombatantDefinition:
            result = visit(compendiumCombatantDefinition: &comp) || result
            combatant.definition = comp
        default:
            assertionFailure("Unexpected combatant definition in ParseableVisitor")
        }

        result = optionalVisit(&combatant.party, visit: visit) || result

        return result
    }

    @VisitorBuilder
    open func visit(adHocCombatantDefinition: inout AdHocCombatantDefinition) -> Bool {
        visit(statBlock: &adHocCombatantDefinition.stats)
        optionalVisit(&adHocCombatantDefinition.original, visit: visit)
    }

    @VisitorBuilder
    open func visit(compendiumCombatantDefinition: inout CompendiumCombatantDefinition) -> Bool {
        switch compendiumCombatantDefinition.item {
        case var monster as Monster:
            visit(monster: &monster)
            compendiumCombatantDefinition.item = monster
        case var character as Character:
            visit(character: &character)
            compendiumCombatantDefinition.item = character
        default:
            assertionFailure("Unexpected CompendiumCombatant in visitor")
            false
        }
    }

    open func visit(monster: inout Monster) -> Bool {
        return visit(statBlock: &monster.stats)
    }

    open func visit(character: inout Character) -> Bool {
        return visit(statBlock: &character.stats)
    }

    open func visit(spell: inout Spell) -> Bool {
        return false
    }

    open func visit(group: inout CompendiumItemGroup) -> Bool {
        return visitEach(
            model: &group,
            toCollection: \.members,
            visit: visit(itemReference:)
        )
    }

    @VisitorBuilder
    open func visit(statBlock: inout StatBlock) -> Bool {
        for idx in statBlock.features.indices {
            optionalVisit(&statBlock.features[idx].result) { result in
                optionalVisit(&result.value) { parsedFeature in
                    optionalVisit(&parsedFeature.spellcasting) { spellcasting in
                        optionalVisit(&spellcasting.spellsByLevel) { spellsByLevel in
                            var result = false
                            for key in spellsByLevel.keys {
                                result = optionalVisit(&spellsByLevel[key]) { locatedSpells in
                                    var result = false
                                    for idx in locatedSpells.indices {
                                        result = optionalVisit(&locatedSpells[idx].value.resolvedTo, visit: visit) || result
                                    }
                                    return result
                                } || result
                            }
                            return false
                        }
                    }
                }
            }
        }
    }

    open func visit(itemReference: inout CompendiumItemReference) -> Bool {
        return false
    }

    open func visit(job: inout CompendiumImportJob) -> Bool {
        return false
    }
}
