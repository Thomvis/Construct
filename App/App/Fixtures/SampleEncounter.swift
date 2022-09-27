//
//  SampleEncounter.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import GameModels
import Helpers

enum SampleEncounter {

    // Creates a sample encounter and sets it as the scratch pad
    static func create(with env: Environment) -> Effect<AppState.Action, Never> {
        // create sample encounter and save to scratch pad
        let spe: Encounter? = try? env.database.keyValueStore.get(
            Encounter.key(Encounter.scratchPadEncounterId),
            crashReporter: env.crashReporter
        )

        let encounter = createEncounter(with: env, existing: spe)
        try? env.database.keyValueStore.put(encounter)

        return .none
    }

    static func createEncounter(with env: Environment, existing spe: Encounter? = nil) -> Encounter {
        var combatants: [Combatant] = []
        if let entry = try? env.database.keyValueStore.get(
            CompendiumItemKey(type: .monster, realm: .core, identifier: "Mummy"),
            crashReporter: env.crashReporter
        ),
            let mummy = entry.item as? Monster
        {
            combatants.append(Combatant(monster: mummy))
        }

        if let entry = try? env.database.keyValueStore.get(
            CompendiumItemKey(type: .monster, realm: .core, identifier: "Giant Spider"),
            crashReporter: env.crashReporter
        ),
            let spider = entry.item as? Monster
        {
            combatants.append(Combatant(monster: spider))
            combatants.append(Combatant(monster: spider))
        }

        combatants.append(contentsOf: [
            Combatant(adHoc: AdHocCombatantDefinition(id: UUID().tagged(), stats: apply(StatBlock.default) {
                $0.name = "Ennan Yarfall" // fighter
                $0.hitPoints = 27
                $0.armorClass = 18
                $0.initiative = Initiative(modifier: Modifier(modifier: 1), advantage: false)
            }, player: Player(name: "Robin"), level: 3, original: nil)),

            Combatant(adHoc: AdHocCombatantDefinition(id: UUID().tagged(), stats: apply(StatBlock.default) {
                $0.name = "Willow" // rogue
                $0.hitPoints = 20
                $0.armorClass = 13
                $0.initiative = Initiative(modifier: Modifier(modifier: 3), advantage: false)
            }, player: Player(name: "Max"), level: 3, original: nil)),

            Combatant(adHoc: AdHocCombatantDefinition(id: UUID().tagged(), stats: apply(StatBlock.default) {
                $0.name = "Umún Dundelver" // cleric
                $0.hitPoints = 22
                $0.armorClass = 16
                $0.initiative = Initiative(modifier: Modifier(modifier: 1), advantage: false)
            }, player: Player(name: "Jamie"), level: 3, original: nil)),

            Combatant(adHoc: AdHocCombatantDefinition(id: UUID().tagged(), stats: apply(StatBlock.default) {
                $0.name = "Sarovin a'Ryr" // warlock
                $0.hitPoints = 20
                $0.armorClass = 14
                $0.initiative = Initiative(modifier: Modifier(modifier: 2), advantage: false)
            }, player: Player(name: "Chris"), level: 3, original: nil)),
        ])

        return Encounter(id: Encounter.scratchPadEncounterId.rawValue, name: spe?.name.nonEmptyString ?? "Scratch pad", combatants: combatants)
    }
}
