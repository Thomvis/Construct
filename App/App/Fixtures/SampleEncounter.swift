//
//  SampleEncounter.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import Compendium
import GameModels
import Helpers
import Persistence

enum SampleEncounter {

    // Backwards-compatible helper used by tests/snapshots.
    // Defaults to 2014 content to match previous behavior.
    static func createEncounter(
        database: Database,
        crashReporter: CrashReporter
    ) -> Encounter {
        createEncounter(
            database: database,
            crashReporter: crashReporter,
            ruleset: .rules2014,
            id: UUID(),
            name: "Sample encounter"
        )
    }

    // Creates a sample encounter from the selected rules edition.
    // If the scratch pad is empty, it is replaced.
    // Otherwise a new top-level encounter is created with a unique name.
    @discardableResult
    static func restore(
        database: Database,
        crashReporter: CrashReporter,
        ruleset: DefaultContentRuleset
    ) -> Encounter? {
        let scratchPad: Encounter? = try? database.keyValueStore.get(
            Encounter.key(Encounter.scratchPadEncounterId),
            crashReporter: crashReporter
        )

        let shouldUseScratchPad = scratchPad?.combatants.isEmpty != false
        if shouldUseScratchPad {
            let encounter = createEncounter(
                database: database,
                crashReporter: crashReporter,
                ruleset: ruleset,
                id: Encounter.scratchPadEncounterId.rawValue,
                name: scratchPad?.name.nonEmptyString ?? "Scratch pad"
            )
            try? database.keyValueStore.put(encounter)
            return encounter
        } else {
            let name = uniqueTopLevelEncounterName(database: database, preferredName: "Sample encounter")
            let encounter = createEncounter(
                database: database,
                crashReporter: crashReporter,
                ruleset: ruleset,
                id: UUID(),
                name: name
            )

            do {
                try database.keyValueStore.put(encounter)
                try database.keyValueStore.put(
                    CampaignNode(
                        id: UUID().tagged(),
                        title: name,
                        contents: .init(key: encounter.key.rawValue, type: .encounter),
                        special: nil,
                        parentKeyPrefix: CampaignNode.root.keyPrefixForChildren.rawValue
                    )
                )
            } catch {
                return nil
            }

            return encounter
        }
    }

    private static func createEncounter(
        database: Database,
        crashReporter: CrashReporter,
        ruleset: DefaultContentRuleset,
        id: UUID,
        name: String
    ) -> Encounter {
        let preferredRealms = preferredMonsterRealms(for: ruleset)

        var combatants: [Combatant] = []
        if let mummy = loadMonster(
            "Mummy",
            preferredRealms: preferredRealms,
            database: database,
            crashReporter: crashReporter
        ) {
            combatants.append(Combatant(monster: mummy))
        }

        if let spider = loadMonster(
            "Giant Spider",
            preferredRealms: preferredRealms,
            database: database,
            crashReporter: crashReporter
        ) {
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

        return apply(Encounter(id: id, name: name, combatants: combatants)) {
            $0.partyForDifficulty = .combatant(.init(filter: nil))
        }
    }

    private static func preferredMonsterRealms(for ruleset: DefaultContentRuleset) -> [CompendiumRealm.Id] {
        switch ruleset {
        case .rules2014:
            return [CompendiumRealm.core.id]
        case .rules2024:
            return [CompendiumRealm.core2024.id]
        }
    }

    private static func loadMonster(
        _ identifier: String,
        preferredRealms: [CompendiumRealm.Id],
        database: Database,
        crashReporter: CrashReporter
    ) -> Monster? {
        for realm in preferredRealms {
            if let entry = try? database.keyValueStore.get(
                CompendiumItemKey(type: .monster, realm: .init(realm), identifier: identifier),
                crashReporter: crashReporter
            ),
               let monster = entry.item as? Monster {
                return monster
            }
        }
        return nil
    }

    private static func uniqueTopLevelEncounterName(database: Database, preferredName: String) -> String {
        let existingNodes: [CampaignNode] = (try? database.keyValueStore.fetchAll(
            .keyPrefix(CampaignNode.root.keyPrefixForFetchingDirectChildren)
        )) ?? []
        let existingNames = Set(existingNodes.map(\.title))

        if !existingNames.contains(preferredName) {
            return preferredName
        }

        var suffix = 2
        while true {
            let candidate = "\(preferredName) \(suffix)"
            if !existingNames.contains(candidate) {
                return candidate
            }
            suffix += 1
        }
    }
}
