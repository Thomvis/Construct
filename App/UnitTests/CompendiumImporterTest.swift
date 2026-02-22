//
//  CompendiumImporterTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 19/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine
import Compendium
import Persistence
import GameModels
import TestSupport

class CompendiumImporterTest: XCTestCase {

    var compendium: DatabaseCompendium!
    var compendiumMetadata: CompendiumMetadata!
    var keyValueStore: KeyValueStore!

    override func setUp() async throws {
        try await super.setUp()

        let db = try! await Database(path: nil, source: Database(path: InitialDatabase.path))
        self.compendium = DatabaseCompendium(databaseAccess: db.access)
        self.compendiumMetadata = CompendiumMetadata.live(db)
        self.keyValueStore = db.keyValueStore
    }

    func test() async throws {

        let sut = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)
        let item = Fixtures.monster
        let task = CompendiumImportTask(
            sourceId: .defaultMonsters,
            sourceVersion: nil,
            reader: DummyCompendiumDataSourceReader(items: [item]),
            document: CompendiumSourceDocument.unspecifiedCore,
            overwriteExisting: false
        )

        let result = try await sut.run(task)
        XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 1, overwrittenItemCount: 0, invalidItemCount: 0))

        let entry = try! keyValueStore.get(item.key)
        XCTAssertEqual(entry?.item.title, item.title)
    }

    func testOverwritingDisabled() async throws {
        let sut = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)
        var item = Fixtures.monster

        let task = CompendiumImportTask(
            sourceId: .defaultMonsters,
            sourceVersion: nil,
            reader: DummyCompendiumDataSourceReader(items: [item]),
            document: CompendiumSourceDocument.unspecifiedCore,
            overwriteExisting: false
        )

        _ = try await sut.run(task)

        // change the item and import it again
        item.stats.hitPoints = 1000
        let result = try await sut.run(task)
        XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 0, overwrittenItemCount: 0, invalidItemCount: 0))

        let entry = try! keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 3)
    }

    func testOverwritingEnabled() async throws {
        let sut = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)
        var item = Fixtures.monster

        let task = CompendiumImportTask(
            sourceId: .defaultMonsters,
            sourceVersion: nil,
            reader: DummyCompendiumDataSourceReader(items: [item]),
            document: CompendiumSourceDocument.unspecifiedCore,
            overwriteExisting: false
        )

        _ = try await sut.run(task)

        // change the item and import it again
        item.stats.hitPoints = 1000
        let task2 = CompendiumImportTask(
            sourceId: .defaultMonsters,
            sourceVersion: nil,
            reader: DummyCompendiumDataSourceReader(items: [item]),
            document: CompendiumSourceDocument.unspecifiedCore,
            overwriteExisting: true
        )

        let result = try await sut.run(task2)
        XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 0, overwrittenItemCount: 1, invalidItemCount: 0))

        let entry = try! keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 1000)
    }

    func testUsesTaskDocumentRealmForReader() async throws {
        let sut = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)

        let document = CompendiumSourceDocument(
            id: .init("custom-homebrew"),
            displayName: "Custom Homebrew",
            realmId: CompendiumRealm.homebrew.id
        )
        try compendiumMetadata.createDocument(document)

        let task = CompendiumImportTask(
            sourceId: .defaultMonsters,
            sourceVersion: nil,
            reader: RealmAwareDummyCompendiumDataSourceReader { realmId in
                var stats = StatBlock.default
                stats.name = "Realm Routed Monster"
                return Monster(
                    realm: .init(realmId),
                    stats: stats,
                    challengeRating: .half
                )
            },
            document: document,
            overwriteExisting: true
        )

        _ = try await sut.run(task)

        let key = CompendiumItemKey(
            type: .monster,
            realm: .init(CompendiumRealm.homebrew.id),
            identifier: "Realm Routed Monster"
        )
        let entry = try keyValueStore.get(key)

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.item.key.realm.value, CompendiumRealm.homebrew.id)
    }
}

struct DummyCompendiumDataSourceReader: CompendiumDataSourceReader {
    static var name = "DummyCompendiumDataSourceReader"

    let dataSource: any CompendiumDataSource<Data> = DummyCompendiumDataSource()
    let items: [CompendiumItem]

    func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
        items.map {CompendiumDataSourceReaderOutput.item($0) }.async.stream
    }
}

struct RealmAwareDummyCompendiumDataSourceReader: CompendiumDataSourceReader {
    static var name = "RealmAwareDummyCompendiumDataSourceReader"

    let dataSource: any CompendiumDataSource<Data> = DummyCompendiumDataSource()
    let makeItem: (CompendiumRealm.Id) -> CompendiumItem

    func items(realmId: CompendiumRealm.Id) throws -> AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error> {
        [CompendiumDataSourceReaderOutput.item(makeItem(realmId))].async.stream
    }
}

struct DummyCompendiumDataSource: CompendiumDataSource {
    static var name = "DummyCompendiumDataSource"
    var bookmark: String = "dummy"

    func read() throws -> AsyncThrowingStream<Data, Error> {
        [Data()].async.stream
    }
}
