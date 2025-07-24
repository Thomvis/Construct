//
//  DatabaseCompendiumTest.swift
//
//
//  Created by Thomas Visser on 07/12/2023.
//

import Foundation
import XCTest
@testable import Persistence
import GameModels
import Compendium
import CustomDump
import Helpers
import TestSupport

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

        XCTAssertEqual(try sut.realms().first, updatedRealm)
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
        
        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Character(name: "Bob", to: &sourceEntry)
                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { _ in
                        // Empty initially
                    }
                    r.Document(name: "hb") { d in
                        d.Party(name: "Party") {
                            sourceEntry.item
                        }
                    }
                }
            }
        }.insert(into: db)

        // Transfer entries from source to target in move mode
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        try await transfer(
            selection, 
            mode: .move, 
            target: CompendiumSourceDocumentKey(targetDocument), 
            conflictResolution: .overwrite, 
            db: db.access
        )

        // Assert final state - character moved from source to target
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument") { _ in
                        // Empty - character was moved
                    }
                    r.Document(name: "targetDocument") { d in
                        d.Character(name: "Bob", to: &sourceEntry)
                    }
                    r.Document(name: "hb") { d in
                        d.Party(name: "Party") {
                            sourceEntry.item
                        }
                    }
                }
            }
        }.assert(db)
    }

    func testTransferMoveMultipleItemsWithoutConflictBetweenRealms() async throws {
        let db = Database.uninitialized
        
        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var targetDocument: CompendiumSourceDocument!
        var entry1: CompendiumEntry!
        var entry2: CompendiumEntry!
        var entry3: CompendiumEntry!
        var partyEntry: CompendiumEntry!
        
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Character(name: "Alice", to: &entry1)
                        d.Character(name: "Bob", to: &entry2)
                        d.Character(name: "Charlie", to: &entry3)

                        d.Party(name: "Party", to: &partyEntry) {
                            entry1.item
                            entry2.item
                            entry3.item
                        }
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { _ in
                        // Empty initially
                    }
                }
            }

            s.Entity(Encounter(
                id: UUID(fakeSeq: 456),
                name: "Encounter",
                combatants: [
                    .init(id: UUID(fakeSeq: 123).tagged(), compendiumCombatant: entry1.item as! Character)
                ]
            ))
        }.insert(into: db)

        // Build a selection to fetch all entries from the source document
        let selection = CompendiumItemSelection.multiple(
            CompendiumFetchRequest(
                search: nil,
                filters: .init(source: .init(sourceDocument)),
                order: nil,
                range: nil
            )
        )

        // Transfer entries in move mode with overwrite conflict resolution
        try await transfer(
            selection,
            mode: .move,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .overwrite,
            db: db.access
        )

        // Assert final state - all characters moved from source to target, references updated
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument") { d in
                        d.Character(name: "Alice", to: &entry1)
                        d.Character(name: "Bob", to: &entry2)
                        d.Character(name: "Charlie", to: &entry3)
                    }
                }

                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") { d in
                        // Empty - all characters were moved, but party doesn't support moving
                        d.Party(name: "Party", to: &partyEntry) {
                            entry1.item
                            entry2.item
                            entry3.item
                        }
                    }
                }
            }

            s.Entity(Encounter(
                id: UUID(fakeSeq: 456),
                name: "Encounter",
                combatants: [
                    .init(id: UUID(fakeSeq: 123).tagged(), compendiumCombatant: entry1.item as! Character)
                ]
            ))
        }.assert(db)
    }

    func testTransferMoveSingleItemWithConflictSkip() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        var targetEntry: CompendiumEntry!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &targetEntry)
                    }
                }
            }
        }.insert(into: db)

        try print(DatabaseKeyValueStore(db.access).dump(.all))
        // Transfer the entry with skip conflict resolution
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        try await transfer(
            selection,
            mode: .move,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .skip,
            db: db.access
        )
        
        // Assert final state - no changes since the conflict was skipped
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &targetEntry)
                    }
                }
            }
        }.assert(db)
    }

    func testTransferMoveSingleItemWithConflictOverwrite() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        var targetEntry: CompendiumEntry!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &targetEntry)
                    }
                }
            }
        }.insert(into: db)

        // Transfer the entry with overwrite conflict resolution
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        try await transfer(
            selection,
            mode: .move,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .overwrite,
            db: db.access
        )
        
        // Assert final state - source monster moved to target, replacing the target monster
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") {_ in
                        // Empty - monster was moved
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }
            }
        }.assert(db)
    }
    
    func testTransferMoveSingleItemWithConflictKeepBoth() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        var targetEntry: CompendiumEntry!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &targetEntry)
                    }
                }
            }
        }.insert(into: db)

        // Transfer the entry with keep both conflict resolution
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        try await transfer(
            selection,
            mode: .move,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .keepBoth,
            db: db.access
        )

        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in

                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A 2", to: &sourceEntry)
                        d.Monster(name: "Monster A", to: &targetEntry)
                    }
                }
            }
        }.assert(db)
    }

    /// Test move of a selection of items of which one is already in the target realm
    func testTransferMoveMultipleItemsAlreadyInTargetRealm() async throws {
        let db = Database.uninitialized
        
        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var targetDocument: CompendiumSourceDocument!
        var bobA: CompendiumEntry!
        var bobB: CompendiumEntry!
        var bobC: CompendiumEntry!
        
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Character(id: 1, name: "Bob A", to: &bobA)
                        d.Character(id: 2, name: "Bob B", to: &bobB)
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        // Bob C is already in the target document
                        d.Character(id: 3, name: "Bob C", to: &bobC)
                    }
                }
            }
        }.insert(into: db)

        // Create a selection that finds all Bobs across both documents
        let selection = CompendiumItemSelection.multiple(
            CompendiumFetchRequest(
                search: "Bob",
                filters: nil,
                order: nil,
                range: nil
            )
        )

        // Transfer all Bobs to target document
        let movedItemKeys = try await transfer(
            selection,
            mode: .move,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .overwrite,
            db: db.access
        )

        XCTAssertEqual(movedItemKeys, [bobA.rawKey, bobB.rawKey])

        // Assert final state - Bob A and Bob B moved to target, Bob C remained unchanged
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") { _ in
                        // Empty - all Bobs were moved
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument") { d in
                        d.Character(id: 1, name: "Bob A", to: &bobA)
                        d.Character(id: 2, name: "Bob B", to: &bobB)
                        d.Character(id: 3, name: "Bob C", to: &bobC) // Unchanged, already in target
                    }
                }
            }
        }.assert(db)
    }

    /// No copy made because the entity conflicts with itself
    func testTransferCopySingleItemWithConflictSkipWithinRealm() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { d in

                    }
                }
            }
        }.insert(into: db)

        // Transfer the entry with skip conflict resolution
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        let copiedItemKeys = try await transfer(
            selection,
            mode: .copy,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .skip,
            db: db.access
        )
        
        // Verify no items were copied
        XCTAssertEqual(copiedItemKeys, [])
        
        // Assert final state - no changes since the conflict was skipped
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { d in

                    }
                }
            }
        }.assert(db)
    }

    /// Effectively no copy made
    func testTransferCopySingleItemWithConflictOverwriteWithinRealm() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { d in

                    }
                }
            }
        }.insert(into: db)

        // Transfer the entry with overwrite conflict resolution
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        let copiedItemKeys = try await transfer(
            selection,
            mode: .copy,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .overwrite,
            db: db.access
        )
        
        // Verify one item was copied
        XCTAssertEqual(copiedItemKeys, [sourceEntry.rawKey])
        
        // Assert final state - source item remains, target item is overwritten with a copy
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in

                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry) // Target item is now a copy of source
                    }
                }
            }
        }.assert(db)
    }

    func testTransferCopySingleItemWithConflictKeepBothWithinRealm() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { d in

                    }
                }
            }
        }.insert(into: db)

        // Transfer the entry with overwrite conflict resolution
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        let copiedItemKeys = try await transfer(
            selection,
            mode: .copy,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .keepBoth,
            db: db.access
        )

        // Verify one item was copied
        XCTAssertEqual(copiedItemKeys, [sourceEntry.rawKey])

        // Assert final state - source item remains, target item is overwritten with a copy
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "realm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A 2", to: &sourceEntry) // Target item is now a copy of source
                    }
                }
            }
        }.assert(db)
    }

    func testTransferCopySingleItemWithoutConflictBetweenRealms() async throws {
        let db = Database.uninitialized

        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        var targetDocument: CompendiumSourceDocument!
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Character(id: 0, name: "Bob", to: &sourceEntry)
                    }
                    r.Document(name: "hb") { d in
                        d.Party(id: 1, name: "Party") {
                            sourceEntry.item
                        }
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { _ in
                        // Empty initially
                    }
                }
            }
        }.insert(into: db)

        // Transfer entry from source to target in copy mode
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)

        try await transfer(
            selection,
            mode: .copy,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .overwrite,
            db: db.access
        )

        // Assert final state - character copied from source to target
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") { d in
                        d.Character(id: 0, name: "Bob")
                    }
                    r.Document(name: "hb") { d in
                        d.Party(id: 1, name: "Party") {
                            sourceEntry.item
                        }
                    }
                }

                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument") { d in
                        d.Character(id: 0, name: "Bob") // character id does not change, because it does not conflict between realms
                    }
                }
            }
        }.assert(db)
    }

    func testTransferCopyMultipleItemsWithoutConflictBetweenRealms() async throws {
        let db = Database.uninitialized
        
        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var targetDocument: CompendiumSourceDocument!
        var entry1: CompendiumEntry!
        var entry2: CompendiumEntry!
        var entry3: CompendiumEntry!
        
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Character(id: 0, name: "Alice", to: &entry1)
                        d.Character(id: 1, name: "Bob", to: &entry2)
                        d.Character(id: 2, name: "Charlie", to: &entry3)
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { _ in
                        // Empty initially
                    }
                }
            }
        }.insert(into: db)

        // Build a selection to fetch all entries from the source document
        let selection = CompendiumItemSelection.multiple(
            CompendiumFetchRequest(
                search: nil,
                filters: .init(source: .init(sourceDocument)),
                order: nil,
                range: nil
            )
        )

        // Transfer entries in copy mode
        let copiedItemKeys = try await transfer(
            selection,
            mode: .copy,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .overwrite,
            db: db.access
        )

        XCTAssertEqual(Set(copiedItemKeys), Set([entry1.rawKey, entry2.rawKey, entry3.rawKey]))

        // Assert final state - all characters copied to target while remaining in source
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") { d in
                        d.Character(id: 0, name: "Alice")
                        d.Character(id: 1, name: "Bob")
                        d.Character(id: 2, name: "Charlie")
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument") { d in
                        d.Character(id: 0, name: "Alice")
                        d.Character(id: 1, name: "Bob")
                        d.Character(id: 2, name: "Charlie")
                    }
                }
            }
        }.assert(db)
    }

    func testTransferCopyMultipleItemsWithConflictKeepBoth() async throws {
        let db = Database.uninitialized
        
        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var targetDocument: CompendiumSourceDocument!
        var sourceEntry1: CompendiumEntry!
        var sourceEntry2: CompendiumEntry!
        var targetEntry1: CompendiumEntry!
        
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry1)
                        d.Monster(name: "Monster B", to: &sourceEntry2)
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument", to: &targetDocument) { d in
                        d.Monster(name: "Monster A", to: &targetEntry1)
                    }
                }
            }
        }.insert(into: db)

        // Create selection for all monsters in source document
        let selection = CompendiumItemSelection.multiple(
            CompendiumFetchRequest(
                search: nil,
                filters: .init(source: .init(sourceDocument)),
                order: nil,
                range: nil
            )
        )

        // Transfer with keep both conflict resolution
        let copiedItemKeys = try await transfer(
            selection,
            mode: .copy,
            target: CompendiumSourceDocumentKey(targetDocument),
            conflictResolution: .keepBoth,
            db: db.access
        )

        XCTAssertEqual(Set(copiedItemKeys), Set([sourceEntry1.rawKey, sourceEntry2.rawKey]))

        // Assert final state - both items copied, with duplicated item renamed
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") { d in
                        d.Monster(name: "Monster A", to: &sourceEntry1)
                        d.Monster(name: "Monster B", to: &sourceEntry2)
                    }
                }
                c.Realm(name: "targetRealm") { r in
                    r.Document(name: "targetDocument") { d in
                        d.Monster(name: "Monster A", to: &targetEntry1)
                        d.Monster(name: "Monster A 2")
                        d.Monster(name: "Monster B")
                    }
                }
            }
        }.assert(db)
    }

    func testTransferToInvalidTargetDocument() async throws {
        let db = Database.uninitialized
        
        // Setup compendium
        var sourceDocument: CompendiumSourceDocument!
        var sourceEntry: CompendiumEntry!
        
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument", to: &sourceDocument) { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }
            }
        }.insert(into: db)

        // Create an invalid target document key (document doesn't exist)
        let invalidTarget = CompendiumSourceDocumentKey(
            CompendiumSourceDocument(id: "nonexistent", displayName: "Nonexistent", realmId: "sourceRealm")
        )

        // Attempt to transfer to invalid target should throw an error
        let selection = CompendiumItemSelection.single(sourceEntry.item.key)
        
        do {
            _ = try await transfer(
                selection,
                mode: .move,
                target: invalidTarget,
                conflictResolution: .overwrite,
                db: db.access
            )
            XCTFail("Expected transfer to fail with invalid target document")
        } catch {
            // Should throw some kind of error
            XCTAssertTrue(true, "Transfer correctly failed with invalid target document")
        }
        
        // Assert final state - source entry should remain unchanged
        try KeyValueStoreDefinition { s in
            s.Compendium { c in
                c.Realm(name: "sourceRealm") { r in
                    r.Document(name: "sourceDocument") { d in
                        d.Monster(name: "Monster A", to: &sourceEntry)
                    }
                }
            }
        }.assert(db)
    }

    private struct KeyValueStoreDefinition {

        var compendium: CompendiumDefinition?
        var entities: [any KeyValueStoreEntity] = []

        @discardableResult
        init(contents: (inout KeyValueStoreDefinition) -> Void) throws {
            contents(&self)
        }

        mutating func Compendium(_ contents: (inout CompendiumDefinition) -> Void) {
            let compendium = CompendiumDefinition(contents: contents)
            self.compendium = compendium
        }

        mutating func Entity<E: KeyValueStoreEntity>(_ entity: E) {
            self.entities.append(entity)
        }

        mutating func Entity<E: KeyValueStoreEntity>(_ entity: E, to: inout E?) {
            self.entities.append(entity)
            to = entity
        }

        func insert(into db: Database) throws {
            try self.compendium?.insert(into: db)

            for entity in entities {
                try db.keyValueStore.put(entity)
            }
        }

        func assert(_ db: Database, file: StaticString = #filePath, line: UInt = #line) throws {
            let db2 = Database.uninitialized
            try insert(into: db2)

            try XCTAssertNoDifference(
                DatabaseKeyValueStore(db.access).dump(.all),
                DatabaseKeyValueStore(db2.access).dump(.all),
                file: file,
                line: line
            )
        }
    }

    private struct CompendiumDefinition {
        private var realms: [RealmDefinition] = []
        var uuidGenerator = UUID.fakeGenerator()

        @discardableResult
        init(contents: (inout CompendiumDefinition) -> Void) {
            contents(&self)
        }

        mutating func Realm(name: String, to: inout CompendiumRealm?, contents: (inout RealmDefinition) -> Void) {
            to = Realm(name: name, contents: contents)
        }

        @discardableResult
        mutating func Realm(name: String, contents: (inout RealmDefinition) -> Void) -> CompendiumRealm {
            var realm = RealmDefinition(name: name, compendium: self)
            contents(&realm)
            realms.append(realm)
            return realm.value
        }

        func insert(into db: Database) throws {
            let compendium = DatabaseCompendium(databaseAccess: db.access)
            let metadata = CompendiumMetadata.live(db)

            for realm in realms {
                try metadata.createRealm(realm.value)

                for document in realm.documents {
                    try metadata.createDocument(document.value)

                    for entry in document.entries {
                        try compendium.put(entry)
                    }
                }
            }
        }
    }

    private struct RealmDefinition {
        let name: String
        let compendium: CompendiumDefinition

        var documents: [SourceDocumentDefinition] = []

        mutating func Document(name: String, to: inout CompendiumSourceDocument?, contents: (inout SourceDocumentDefinition) -> Void) {
            to = Document(name: name, contents: contents)
        }

        @discardableResult
        mutating func Document(name: String, contents: (inout SourceDocumentDefinition) -> Void) -> CompendiumSourceDocument {
            var document = SourceDocumentDefinition(name: name, realm: self)
            contents(&document)
            documents.append(document)

            return document.value
        }

        var value: CompendiumRealm {
            CompendiumRealm(id: .init(name), displayName: name)
        }
    }

    private struct SourceDocumentDefinition {
        let name: String
        let realm: RealmDefinition

        var entries: [CompendiumEntry] = []

        var value: CompendiumSourceDocument {
            CompendiumSourceDocument(id: .init(name), displayName: name, realmId: .init(realm.name))
        }

        mutating func Monster(name: String, to: inout CompendiumEntry?) {
            to = Monster(name: name)
        }

        @discardableResult
        mutating func Monster(name: String) -> CompendiumEntry {
            Item(GameModels.Monster(
                realm: .init(.init(realm.name)),
                stats: StatBlock(name: name),
                challengeRating: .oneQuarter
            ))
        }

        mutating func Character(id: Int? = nil, name: String, to: inout CompendiumEntry?) {
            to = Character(id: id, name: name)
        }

        @discardableResult
        mutating func Character(id: Int? = nil, name: String) -> CompendiumEntry {
            Item(GameModels.Character(
                id: .init(id.map(UUID.init(fakeSeq:)) ?? realm.compendium.uuidGenerator()),
                realm: .init(.init(realm.name)),
                stats: StatBlock(name: name)
            ))
        }

        mutating func Party(
            id: Int? = nil,
            name: String,
            to: inout CompendiumEntry?,
            @ArrayBuilder<CompendiumItem> members: () -> [CompendiumItem]
        ) {
            to = Party(id: id, name: name, members: members)
        }

        @discardableResult
        mutating func Party(
            id: Int? = nil,
            name: String,
            @ArrayBuilder<CompendiumItem> members: () -> [CompendiumItem]
        ) -> CompendiumEntry {
            Item(GameModels.CompendiumItemGroup(
                id: .init(id.map(UUID.init(fakeSeq:)) ?? realm.compendium.uuidGenerator()),
                title: .init(name),
                members: members().map(CompendiumItemReference.init)
            ))
        }

        @discardableResult
        mutating func Item(_ item: CompendiumItem) -> CompendiumEntry {
            let entry = CompendiumEntry(item, origin: .created(nil), document: .init(id: .init(name), displayName: name))
            entries.append(entry)
            return entry
        }
    }

}
