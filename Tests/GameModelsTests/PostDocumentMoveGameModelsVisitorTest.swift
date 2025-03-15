import Foundation
import GameModels
import XCTest
import SnapshotTesting
import TestSupport
import Helpers
import CustomDump

final class PostDocumentMoveGameModelsVisitorTest: XCTestCase {

    var fixtures: Fixtures!

    override func setUp() {
        super.setUp()

        self.fixtures = Fixtures()
    }

    func testUpdateCompendiumDisplayName() {
        let updatedDocument = apply(fixtures.document) {
            $0.displayName = "Doc 2"
        }

        let sut = PostDocumentMoveGameModelsVisitor(
            updatedDocument: updatedDocument,
            originalRealmId: fixtures.document.realmId,
            originalDocumentId: fixtures.document.id,
            moving: nil
        )

        // Asserting that:
        // - visit returns true
        // - in the snapshot:
        //   - the name of the document in the entry changed
        // - a second visit returns false
        var visitedEntryInDocument1 = fixtures.entryInDocument1
        XCTAssertTrue(sut.visit(entry: &visitedEntryInDocument1))
        assertSnapshot(of: diff(fixtures.entryInDocument1, visitedEntryInDocument1) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryInDocument1))

        // Asserting that:
        // - visit returns true
        // - in the snapshot:
        //   - the name of the document in the entry changed
        // - a second visit returns false
        var visitedEntryInDocument2 = fixtures.entryInDocument2
        XCTAssertTrue(sut.visit(entry: &visitedEntryInDocument2))
        assertSnapshot(of: diff(fixtures.entryInDocument2, visitedEntryInDocument2) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryInDocument2))

        // Asserting that:
        // - visit returns false
        // - no changes were made to the enty
        var visitedEntryNotInDocument = fixtures.entryNotInDocument
        XCTAssertFalse(sut.visit(entry: &visitedEntryNotInDocument))
        XCTAssertEqual(fixtures.entryNotInDocument, visitedEntryNotInDocument)
    }

    func testUpdateCompendiumId() {
        let updatedDocument = apply(fixtures.document) {
            $0.id = .init("newdoc")
        }

        let sut = PostDocumentMoveGameModelsVisitor(
            updatedDocument: updatedDocument,
            originalRealmId: fixtures.document.realmId,
            originalDocumentId: fixtures.document.id,
            moving: nil
        )

        // Asserting that:
        // - visit returns true
        // - in the snapshot:
        //   - the id of the document in the entry changed
        // - a second visit returns false
        var visitedEntryInDocument1 = fixtures.entryInDocument1
        XCTAssertTrue(sut.visit(entry: &visitedEntryInDocument1))
        assertSnapshot(of: diff(fixtures.entryInDocument1, visitedEntryInDocument1) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryInDocument1))

        // Asserting that:
        // - visit returns true
        // - in the snapshot:
        //   - the id of the document in the entry changed
        // - a second visit returns false
        var visitedEntryInDocument2 = fixtures.entryInDocument2
        XCTAssertTrue(sut.visit(entry: &visitedEntryInDocument2))
        assertSnapshot(of: diff(fixtures.entryInDocument2, visitedEntryInDocument2) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryInDocument2))

        // Asserting that:
        // - visit returns false
        // - no changes were made to the enty
        var visitedEntryNotInDocument = fixtures.entryNotInDocument
        XCTAssertFalse(sut.visit(entry: &visitedEntryNotInDocument))
        XCTAssertEqual(fixtures.entryNotInDocument, visitedEntryNotInDocument)

        var visitedImportJob = fixtures.importJob
        XCTAssertTrue(sut.visit(job: &visitedImportJob))
        assertSnapshot(of: diff(fixtures.importJob, visitedImportJob) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(job: &visitedImportJob))
    }

    func testUpdateCompendiumRealmId() {
        let updatedDocument = apply(fixtures.document) {
            $0.realmId = .init("newrealm")
        }

        let sut = PostDocumentMoveGameModelsVisitor(
            updatedDocument: updatedDocument,
            originalRealmId: fixtures.document.realmId,
            originalDocumentId: fixtures.document.id,
            moving: [
                fixtures.entryInDocument1.item.key,
                fixtures.entryInDocument2.item.key
            ]
        )

        // Asserting that:
        // - visit returns true
        // - in the snapshot:
        //   - the realm id in the item key has changed
        // - a second visit returns false
        var visitedEntryInDocument1 = fixtures.entryInDocument1
        XCTAssertTrue(sut.visit(entry: &visitedEntryInDocument1))
        assertSnapshot(of: diff(fixtures.entryInDocument1, visitedEntryInDocument1) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryInDocument1))

        // Asserting that:
        // - visit returns true
        // - in the snapshot:
        //   - the realm id in the item key has changed
        //   - the realm id in the origin item key has changed
        // - a second visit returns false
        var visitedEntryInDocument2 = fixtures.entryInDocument2
        XCTAssertTrue(sut.visit(entry: &visitedEntryInDocument2))
        assertSnapshot(of: diff(fixtures.entryInDocument2, visitedEntryInDocument2) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryInDocument2))

        // Asserting that:
        // - visit returns false
        // - in the snapshot:
        //   - the realm id in the origin item key has changed
        // - a second visit returns false
        var visitedEntryNotInDocument = fixtures.entryNotInDocument
        XCTAssertTrue(sut.visit(entry: &visitedEntryNotInDocument))
        assertSnapshot(of: diff(fixtures.entryNotInDocument, visitedEntryNotInDocument) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &visitedEntryNotInDocument))

        // Asserting that:
        // - no changes made
        var visitedImportJob = fixtures.importJob
        XCTAssertFalse(sut.visit(job: &visitedImportJob))
        XCTAssertEqual(fixtures.importJob, visitedImportJob)

        // Asserting that:
       // - visit returns true when updating an Encounter's combatant reference that refers to a compendium combatant
       var visitedEncounter = fixtures.encounter
       XCTAssertTrue(sut.visit(encounter: &visitedEncounter))

       // Construct the expected updated key: same type and identifier, but with the new realm id
       let originalKey = fixtures.entryInDocument1.item.key
       let expectedUpdatedKey = CompendiumItemKey(
           type: originalKey.type,
           realm: .init("newrealm"),
           identifier: originalKey.identifier
       )

       // Verify that the combatant's definition now has the updated key
       let updatedKey = (visitedEncounter.combatants.first!.definition as! CompendiumCombatantDefinition).item.key
       XCTAssertEqual(updatedKey, expectedUpdatedKey)

       // A second visit should return false
       XCTAssertFalse(sut.visit(encounter: &visitedEncounter))
    }

    struct Fixtures {
        let uuidGenerator = UUID.fakeGenerator()

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

}
