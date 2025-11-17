import Foundation
import GameModels
import XCTest
import TestSupport
import Helpers
import ComposableArchitecture

/// Shared fixtures for visitor tests
struct VisitorTestFixtures {
    let uuidGenerator = UUIDGenerator.fake()

    let realm: CompendiumRealm
    let document: CompendiumSourceDocument
    let entryInDocument1: CompendiumEntry
    let entryInDocument2: CompendiumEntry
    let entryNotInDocument: CompendiumEntry

    let importJob: CompendiumImportJob
    let encounter: Encounter

    init() {
        realm = CompendiumRealm(id: .init(rawValue: "realm"), displayName: "Realm")
        document = CompendiumSourceDocument(
            id: .init(rawValue: "doc"),
            displayName: "Doc",
            realmId: realm.id
        )

        entryInDocument1 = CompendiumEntry(
            Monster(
                realm: .init(realm.id),
                stats: apply(StatBlock.default) { $0.name = "OG" },
                challengeRating: .half
            ),
            origin: .created(.init(
                itemTitle: "OG",
                itemKey: CompendiumItemKey(
                    type: .monster,
                    realm: .init(realm.id),
                    identifier: "og"
                ))),
            document: .init(document)
        )

        // Also in the document, refers to entry 1
        entryInDocument2 = CompendiumEntry(
            Monster(
                realm: .init(realm.id),
                stats: StatBlock.default,
                challengeRating: .half
            ),
            origin: .created(.init(entryInDocument1.item)),
            document: .init(document)
        )

        // Refers to entry 2
        entryNotInDocument = CompendiumEntry(
            Character(
                id: uuidGenerator().tagged(),
                realm: .init(realm.id),
                stats: StatBlock.default
            ),
            origin: .created(.init(entryInDocument2.item)),
            document: .init(id: .init(rawValue: "od"), displayName: "Other doc")
        )

        importJob = CompendiumImportJob(
            sourceId: .init(type: "a", bookmark: "b"),
            sourceVersion: nil,
            documentId: document.id,
            timestamp: Date.init(timeIntervalSince1970: 0),
            uuid: uuidGenerator()
        )
        encounter = Encounter(
            name: "Encounter",
            combatants: [
                .init(compendiumCombatant: entryInDocument1.item as! Monster)
            ]
        )
    }
} 
