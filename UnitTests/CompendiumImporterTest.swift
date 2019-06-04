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

class CompendiumImporterTest: XCTestCase {

    var compendium: Compendium!

    override func setUp() {
        super.setUp()

        self.compendium = Compendium(try! Database(path: nil))
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
        }, receiveValue: { _ in })

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
        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting:  false)).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 3)
    }

    func testOverwritingEnabled() {
        let sut = CompendiumImporter(compendium: compendium)
        var item = Fixtures.monster

        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting: true)).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        // change the item and import it again
        item.stats.hitPoints = 1000
        _ = sut.run(CompendiumImportTask(reader: DummyCompendiumDataSourceReader(items: [item]), overwriteExisting: true)).sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        let entry = try! compendium.database.keyValueStore.get(item.key)
        XCTAssertEqual((entry?.item as? Monster)?.stats.hitPoints, 1000)
    }
}

struct DummyCompendiumDataSourceReader: CompendiumDataSourceReader {
    static var name = "DummyCompendiumDataSourceReader"

    let dataSource: CompendiumDataSource = DummyCompendiumDataSource()
    let items: [CompendiumItem]

    func read() -> CompendiumDataSourceReaderJob {
        return Job(items: Publishers.Sequence(sequence: items).eraseToAnyPublisher())
    }

    struct Job: CompendiumDataSourceReaderJob {
        var progress: Progress = Progress(totalUnitCount: 0)
        var items: AnyPublisher<CompendiumItem, Error>
    }
}

struct DummyCompendiumDataSource: CompendiumDataSource {
    static var name = "DummyCompendiumDataSource"
    var bookmark: Data? = nil

    func read() -> AnyPublisher<Data, Error> {
        return Empty().eraseToAnyPublisher()
    }
}
