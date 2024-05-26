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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata

        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        XCTAssertEqual(try sut.realms().first, realm)
    }

    func testMetadataCreateRealmThrowsResourceAlreadyExists() throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
        try sut.createRealm(CompendiumRealm(id: "a", displayName: "A"))

        let realm = CompendiumRealm(id: "a", displayName: "Abc")
        XCTAssertThrowsError(try sut.createRealm(realm)) { error in
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceAlreadyExists)
        }
    }

    func testMetadataUpdateRealm() async throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
        try sut.createRealm(CompendiumRealm(id: "a", displayName: "A"))

        let realm = CompendiumRealm(id: "a", displayName: "Abc")
        try await sut.updateRealm(realm)

        XCTAssertEqual(try sut.realms().first, realm)
    }

    func testMetadataUpdateRealmThrowsResourceNotFound() async throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata

        let realm = CompendiumRealm(id: "a", displayName: "Abc")

        do {
            try await sut.updateRealm(realm)
            XCTFail("Expected update to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.resourceNotFound)
        }
    }

    func testMetadataRemoveRealm() async throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        try await sut.removeRealm(realm.id)
        XCTAssertEqual(try sut.realms(), [])
    }

    func testMetadataRemoveRealmThrowsResourceNotFound() async throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)
        try sut.createDocument(doc)

        XCTAssertEqual(try sut.sourceDocuments().first, doc)
    }

    func testMetadataCreateDocumentThrowsResourceAlreadyExists() throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata

        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: .init("a"))

        do {
            try sut.createDocument(doc)
            XCTFail("Expected creation to fail")
        } catch {
            XCTAssertEqual(error as! CompendiumMetadataError, CompendiumMetadataError.invalidRealmId)
        }
    }

    func testMetadataUpdateDocumentNewDisplayName() async throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
        let realm = CompendiumRealm(id: "a", displayName: "A")
        try sut.createRealm(realm)
        let doc = CompendiumSourceDocument(id: .init("doc"), displayName: "Doc", realmId: realm.id)
        try sut.createDocument(doc)

        let newDoc = CompendiumSourceDocument(id: doc.id, displayName: "NewDoc", realmId: doc.realmId)

        try await sut.updateDocument(newDoc, doc.realmId, doc.id)

        XCTAssertEqual(try sut.sourceDocuments().first?.displayName, newDoc.displayName)
    }

    func testMetadataUpdateDocumentNewDisplayNameThrowsResourceNotFound() async throws {
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let compendium = DatabaseCompendium(database: Database.uninitialized)
        let sut = compendium.metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
        let sut = DatabaseCompendium(database: Database.uninitialized).metadata
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
}
