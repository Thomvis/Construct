//
//  DatabaseCompendiumTest.swift
//
//
//  Created by Thomas Visser on 07/12/2023.
//

import Foundation
import XCTest
@testable import Persistence
import GRDB
import GameModels
import Compendium
import CustomDump
import Helpers

class DatabaseCompendiumTest: XCTestCase {

    func testMetadataCreateRealm() throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)

        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        XCTAssertEqual(try sut.realms().first, realm)
    }

    func testMetadataCreateRealmThrowsResourceAlreadyExists() throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        try sut.createRealm(CompendiumRealm(id: "a", displayName: "A"))

        let realm = CompendiumRealm(id: "a", displayName: "Abc")
        XCTAssertThrowsError(try sut.createRealm(realm)) { error in
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceAlreadyExists)
        }
    }

    func testMetadataUpdateRealm() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        let updatedRealm = CompendiumRealm(id: realm.id, displayName: "Abc")
        try await sut.updateRealm(realm.id, updatedRealm.displayName)

        XCTAssertEqual(try sut.realms().first, realm)
    }

    func testMetadataUpdateRealmThrowsResourceNotFound() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)

        let realm = CompendiumRealm(id: "a", displayName: "Abc")

        do {
            try await sut.updateRealm(realm.id, "Abcde")
            XCTFail("Expected update to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceNotFound)
        }
    }

    func testMetadataRemoveRealm() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        try await sut.removeRealm(realm.id)
        XCTAssertEqual(try sut.realms(), [])
    }

    func testMetadataRemoveRealmThrowsResourceNotFound() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        do {
            try await sut.removeRealm(CompendiumRealm.Id("b"))
            XCTFail("Expected removal to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceNotFound)
        }
    }

    func testMetadataRemoveRealmThrowsResourceNotEmpty() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)
        try sut.createDocument(.init(id: .init("doc"), displayName: "Doc", realmId: realm.id))

        do {
            try await sut.removeRealm(realm.id)
            XCTFail("Expected removal to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceNotEmpty)
        }
    }

    func testMetadataCreateDocument() throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)
        try sut.createDocument(doc)

        XCTAssertEqual(try sut.sourceDocuments().first, doc)
    }

    func testMetadataCreateDocumentThrowsResourceAlreadyExists() throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)
        try sut.createDocument(doc)

        do {
            try sut.createDocument(doc)
            XCTFail("Expected creation to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceAlreadyExists)
        }
    }

    func testMetadataCreateDocumentThrowsInvalidRealmId() throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: .init("a"))

        do {
            try sut.createDocument(doc)
            XCTFail("Expected creation to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.invalidRealmId)
        }
    }

    func testMetadataUpdateDocumentNewDisplayName() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)
        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)
        try sut.createDocument(doc)

        let newDoc = CompendiumSourceDocument(id: doc.id, displayName: "NewDoc", realmId: doc.realmId)

        try await sut.updateDocument(newDoc, doc.realmId, doc.id)

        XCTAssertEqual(try sut.sourceDocuments().first?.displayName, newDoc.displayName)
    }

    func testMetadataUpdateDocumentNewDisplayNameThrowsResourceNotFound() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)

        do {
            try await sut.updateDocument(doc, doc.realmId, doc.id)
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceNotFound)
        }
    }

    func testMetadataUpdateDocumentNewId() async throws {
        let db = Database.uninitialized
        let compendium = DatabaseCompendium(databaseAccess: db.access)
        let sut = CompendiumMetadata.live(db)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)
        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)
        try sut.createDocument(doc)

        let entry = CompendiumEntry(
            Character(
                id: .init(),
                realm: .init(realm.id),
                stats: .default
            ),
            origin: .created(nil),
            document: .init(doc)
        )
        try compendium.put(entry)

        let newDoc = CompendiumSourceDocument(id: "b", displayName: "NewDoc", realmId: doc.realmId)

        try await sut.updateDocument(newDoc, doc.realmId, doc.id)

        XCTAssertEqual(try sut.sourceDocuments(), [newDoc])

        let entries = try compendium.fetchAll(filters: .init(source: .init(realm: newDoc.realmId, document: newDoc.id)))
        XCTAssertNoDifference(entries, [apply(entry) { e in
            e.document = .init(newDoc)
        }])
    }

    func testMetadataUpdateDocumentNewIdThrowsResourceAlreadyExists() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)
        let doc1 = CompendiumSourceDocument(id: .init("doc1"), displayName: "Doc 1", realmId: realm.id)
        try sut.createDocument(doc1)
        let doc2 = CompendiumSourceDocument(id: .init("doc2"), displayName: "Doc 2", realmId: realm.id)
        try sut.createDocument(doc2)

        let newDoc1 = CompendiumSourceDocument(id: "doc2", displayName: doc1.displayName, realmId: doc1.realmId)

        do {
            try await sut.updateDocument(newDoc1, doc1.realmId, doc1.id)
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceAlreadyExists)
        }
    }

    func testMetadataUpdateDocumentNewIdThrowsCannotMoveDefaultResource() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm = CompendiumRealm.core
        try sut.createRealm(realm)
        let doc1 = CompendiumSourceDocument.srd5_1
        try sut.createDocument(doc1)
        let doc2 = CompendiumSourceDocument(id: .init("doc2"), displayName: "Doc 2", realmId: realm.id)
        try sut.createDocument(doc2)

        let newDoc1 = CompendiumSourceDocument(id: "doc2", displayName: doc1.displayName, realmId: doc1.realmId)

        do {
            try await sut.updateDocument(newDoc1, doc1.realmId, doc1.id)
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.cannotMoveDefaultResource)
        }
    }

    func testMetadataUpdateDocumentNewRealmId() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm1 = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm1)
        let realm2 = CompendiumRealm(id: "b", displayName: "B")
        try sut.createRealm(realm2)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm1.id)
        try sut.createDocument(doc)

        let newDoc = CompendiumSourceDocument(id: doc.id, displayName: "NewDoc", realmId: realm2.id)

        try await sut.updateDocument(newDoc, doc.realmId, doc.id)

        XCTAssertEqual(try sut.sourceDocuments(), [newDoc])
    }

    func testMetadataUpdateDocumentNewRealmIdThrowsInvalidRealmId() async throws {
        let sut = CompendiumMetadata.live(Database.uninitialized)
        let realm1 = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm1)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm1.id)
        try sut.createDocument(doc)

        let newDoc = CompendiumSourceDocument(id: doc.id, displayName: "NewDoc", realmId: .init("b"))

        do {
            try await sut.updateDocument(newDoc, doc.realmId, doc.id)
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.invalidRealmId)
        }
    }

    func testTransferMoveSingleItemWithoutConflictWithinRealm() async throws {
        let db = Database.uninitialized
        let compendium = DatabaseCompendium(databaseAccess: db.access)
        let metadata = CompendiumMetadata.live(db)

        // Setup source and target realms and documents
        let realm = CompendiumRealm(id: "realm", displayName: "Realm")
        try metadata.createRealm(realm)

        let srcDoc = CompendiumSourceDocument(id: .init("srcDoc"), displayName: "Source Doc", realmId: realm.id)
        let tgtDoc = CompendiumSourceDocument(id: .init("tgtDoc"), displayName: "Target Doc", realmId: realm.id)
        try metadata.createDocument(srcDoc)
        try metadata.createDocument(tgtDoc)

        // Create entries in source document
        let entry = makeCharacter(in: srcDoc, name: "Bob")
        try compendium.put(entry)

        // Transfer entries from source to target in move mode
        let selection = CompendiumItemSelection.single(entry.item.key)

        try await transfer(selection, mode: .move, target: CompendiumSourceDocumentKey(realmId: tgtDoc.realmId, documentId: tgtDoc.id), conflictResolution: .overwrite, db: db.access)

        // Verify source document is empty and target document has the transferred entries
        let srcEntries = try compendium.fetchAll(filters: .init(source: .init(realm: srcDoc.realmId, document: srcDoc.id)))
        XCTAssertEqual(srcEntries.count, 0)

        let tgtEntries = try compendium.fetchAll(filters: .init(source: .init(realm: tgtDoc.realmId, document: tgtDoc.id)))
        XCTAssertEqual(tgtEntries.count, 1)
    }

    func testTransferMoveMultipleItemsWithoutConflictBetweenRealms() async throws {
        let db = Database.uninitialized
        let compendium = DatabaseCompendium(databaseAccess: db.access)
        let metadata = CompendiumMetadata.live(db)

        // Create two distinct realms
        let srcRealm = CompendiumRealm(id: "srcRealm", displayName: "Source Realm")
        let tgtRealm = CompendiumRealm(id: "tgtRealm", displayName: "Target Realm")
        try metadata.createRealm(srcRealm)
        try metadata.createRealm(tgtRealm)

        // Create a source document in the source realm and a target document in the target realm
        let srcDoc = CompendiumSourceDocument(id: .init("srcDoc"), displayName: "Source Doc", realmId: srcRealm.id)
        let tgtDoc = CompendiumSourceDocument(id: .init("tgtDoc"), displayName: "Target Doc", realmId: tgtRealm.id)
        try metadata.createDocument(srcDoc)
        try metadata.createDocument(tgtDoc)

        // Create multiple entries in the source document
        let entry1 = makeCharacter(in: srcDoc, name: "Alice")
        let entry2 = makeCharacter(in: srcDoc, name: "Bob")
        let entry3 = makeCharacter(in: srcDoc, name: "Charlie")
        try compendium.put(entry1)
        try compendium.put(entry2)
        try compendium.put(entry3)

        // Create references to the moving items
        let encounter = Encounter(
            name: "Encounter",
            combatants: [
                .init(compendiumCombatant: entry1.item as! Character)
            ]
        )
        try db.keyValueStore.put(encounter)

        let party = CompendiumItemGroup(
            id: .init(),
            title: "Party",
            members: [
                .init(entry1.item)
            ]
        )
        let partyEntry = CompendiumEntry(
            party,
            origin: .created(nil),
            document: .init(.homebrew)
        )
        try db.keyValueStore.put(partyEntry)

        // Build a selection to fetch all entries from the source document
        let selection = CompendiumItemSelection.multiple(
            CompendiumFetchRequest(
                search: nil,
                filters: .init(source: .init(realm: srcDoc.realmId, document: srcDoc.id)),
                order: nil,
                range: nil
            )
        )

        // Transfer entries in move mode with overwrite conflict resolution
        try await transfer(selection, mode: .move, target: CompendiumSourceDocumentKey(realmId: tgtDoc.realmId, documentId: tgtDoc.id), conflictResolution: .overwrite, db: db.access)

        // Verify the source document is now empty
        let srcEntries = try compendium.fetchAll(filters: .init(source: .init(realm: srcDoc.realmId, document: srcDoc.id)))
        XCTAssertEqual(srcEntries.count, 0)

        // Verify the target document now holds the transferred entries
        let tgtEntries = try compendium.fetchAll(filters: .init(source: .init(realm: tgtDoc.realmId, document: tgtDoc.id)))
        XCTAssertEqual(tgtEntries.count, 3)

        // Ensure each entry has its document and realm updated to that of the target
        for entry in tgtEntries {
            XCTAssertEqual(entry.document.id, tgtDoc.id)
            XCTAssertEqual(entry.item.realm, .init(tgtDoc.realmId))
        }

        // Assert that the encounter reference was updated
        let updatedItemKey = CompendiumItemKey(
            type: entry1.item.key.type,
            realm: .init(tgtRealm.id),
            identifier: entry1.item.key.identifier
        )

        let updatedEncounter = try db.keyValueStore.get(encounter.key)
        XCTAssertEqual((updatedEncounter?.combatants[0].definition as! CompendiumCombatantDefinition).item.key, updatedItemKey)

        // Assert that the party reference was updated
        let updatedParty = try db.keyValueStore.get(party.key)?.item as! CompendiumItemGroup
        XCTAssertEqual(updatedParty.members[0].itemKey, updatedItemKey)
    }

    func makeCharacter(in document: CompendiumSourceDocument, name: String) -> CompendiumEntry {
        let character = Character(
            id: .init(),
            realm: .init(document.realmId),
            stats: apply(.default) { stats in
                stats.name = name
            }
        )
        return CompendiumEntry(
            character,
            origin: .created(nil),
            document: .init(document)
        )
    }

}
