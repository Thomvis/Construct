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

class CompendiumImporterTest: XCTestCase {

    var compendium: DatabaseCompendium!

    override func setUp() {
        super.setUp()

        self.compendium = DatabaseCompendium(database: try! Database(path: nil))
    }

    func test() {
        let sut = CompendiumImporter(compendium: compendium)
        let item = Fixtures.monster
        let task = CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]))

        let e = expectation(description: "Importing ends")
        _ = sut.run(task).sink(receiveCompletion: { completion in
            switch completion {
            case .finished: e.fulfill()
            default: XCTFail()
            }
        }, receiveValue: { result in
            XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 1, overwrittenItemCount: 0, invalidItemCount: 0))
        })

        waitForExpectations(timeout: 2, handler: nil)

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual(entry?.item.title, item.title)
    }

    func testOverwritingDisabled() {
        let sut = CompendiumImporter(compendium: compendium)
        var item = Fixtures.monster

        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting:  false)).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        // change the item and import it again
        item.stats.hitPoints = 1000
        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting:  false)).sink(receiveCompletion: { _ in }, receiveValue: { result in
            XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 0, overwrittenItemCount: 0, invalidItemCount: 0))
        })

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 3)
    }

    func testOverwritingEnabled() {
        let sut = CompendiumImporter(compendium: compendium)
        var item = Fixtures.monster

        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting: true)).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        // change the item and import it again
        item.stats.hitPoints = 1000
        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting: true)).sink(receiveCompletion: { _ in }, receiveValue: { result in
            XCTAssertEqual(result, CompendiumImporter.Result(newItemCount: 0, overwrittenItemCount: 1, invalidItemCount: 0))
        })

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 1000)
    }
}

struct DummyCompendiumDataSourceReader: CompendiumDataSourceReader {
    static var name = "DummyCompendiumDataSourceReader"

    let dataSource: CompendiumDataSource = DummyCompendiumDataSource()
    let items: [CompendiumItem]

    func read() -> CompendiumDataSourceReaderJob {
        return Job(output: Publishers.Sequence(sequence: items).map { .item($0) }.eraseToAnyPublisher())
    }

    struct Job: CompendiumDataSourceReaderJob {
        var output: AnyPublisher<CompendiumDataSourceReaderOutput, CompendiumDataSourceReaderError>
    }
}

struct DummyCompendiumDataSource: CompendiumDataSource {
    static var name = "DummyCompendiumDataSource"
    var bookmark: Data? = nil

    func read() -> AnyPublisher<Data, CompendiumDataSourceError> {
        return Empty().eraseToAnyPublisher()
    }
}
