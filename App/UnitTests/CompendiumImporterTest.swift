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
        let task = CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]))

        let result = try await sut.run(task)
        XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 1, overwrittenItemCount: 0, invalidItemCount: 0))

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual(entry?.item.title, item.title)
    }

    func testOverwritingDisabled() async throws {
        let sut = CompendiumImporter(compendium: compendium)
        var item = Fixtures.monster

        _ = try await sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting:  false))

        // change the item and import it again
        item.stats.hitPoints = 1000
        let result = try await sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting:  false))
        XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 0, overwrittenItemCount: 0, invalidItemCount: 0))

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 3)
    }

    func testOverwritingEnabled() async throws {
        let sut = CompendiumImporter(compendium: compendium)
        var item = Fixtures.monster

        _ = try await sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting: true))

        // change the item and import it again
        item.stats.hitPoints = 1000
        let result = try await sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting: true))
        XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 0, overwrittenItemCount: 1, invalidItemCount: 0))

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 1000)
    }
}

struct DummyCompendiumDataSourceReader: CompendiumDataSourceReader {
    static var name = "DummyCompendiumDataSourceReader"

    let dataSource: CompendiumDataSource = DummyCompendiumDataSource()
    let items: [CompendiumItem]

    func makeJob() -> CompendiumDataSourceReaderJob {
        return Job(output: AsyncThrowingStream(items.map {CompendiumDataSourceReaderOutput.item($0) }.async))
    }

    struct Job: CompendiumDataSourceReaderJob {
        var output: AsyncThrowingStream<CompendiumDataSourceReaderOutput, Error>
    }
}

struct DummyCompendiumDataSource: CompendiumDataSource {
    static var name = "DummyCompendiumDataSource"
    var bookmark: Data? = nil

    func read() -> Data {
        return Data()
    }
}
