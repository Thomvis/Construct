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
import PersistenceTestSupport

class CompendiumImporterTest: XCTestCase {

    var compendium: DatabaseCompendium!

    override func setUp() async throws {
        try await super.setUp()

        let db = try! await Database(path: nil, source: Database(path: InitialDatabase.path))
        self.compendium = DatabaseCompendium(database: db)
    }

    func test() async throws {
        let sut = CompendiumImporter(compendium: compendium)
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

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual(entry?.item.title, item.title)
    }

    func testOverwritingDisabled() async throws {
        let sut = CompendiumImporter(compendium: compendium)
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

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 3)
    }

    func testOverwritingEnabled() async throws {
        let sut = CompendiumImporter(compendium: compendium)
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

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 1000)
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

struct DummyCompendiumDataSource: CompendiumDataSource {
    static var name = "DummyCompendiumDataSource"
    var bookmark: String = "dummy"

    func read() throws -> AsyncThrowingStream<Data, Error> {
        [Data()].async.stream
    }
}
