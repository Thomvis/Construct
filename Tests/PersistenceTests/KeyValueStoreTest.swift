//
//  KeyValueStoreTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Persistence
import GRDB

class KeyValueStoreTest: XCTestCase {
    var db: Persistence.Database!
    var sut: KeyValueStore!

    override func setUp() async throws {
        try await super.setUp()
        let database = try! await Database(path: nil, importDefaultContent: false)
        self.db = database
        self.sut = database.keyValueStore

        // clear Preferences
        try sut.removeAll("")
    }

    func testPutAndGet() {
        try! sut.put(1, at: "1")
        XCTAssertEqual(try! sut.get("1"), 1)
    }

    func testFetchAllSearch() {
        try! sut.put(1, at: "1", fts: FTSDocument(title: "Alpha", subtitle: nil, body: nil))
        try! sut.put(2, at: "2", fts: FTSDocument(title: "Beta", subtitle: nil, body: nil))

        XCTAssertEqual(try! sut.fetchAll(search: "al"), [1])
    }

    func testOverwrite() {
        try! sut.put(1, at: "1")
        try! sut.put(11, at: "1")

        XCTAssertEqual(try! sut.get("1"), 11)
    }

    func testOverwriteWithFTS() {
        try! sut.put(1, at: "1", fts: FTSDocument(title: "Alpha", subtitle: nil, body: nil))
        try! sut.put(11, at: "1", fts: FTSDocument(title: "Omega", subtitle: nil, body: nil))

        XCTAssertEqual(try! sut.fetchAll(search: "Omega"), [11])
    }

    func testUpdateOfNonLastRowFTS() {
        try! sut.put(1, at: "1", fts: FTSDocument(title: "Alpha", subtitle: nil, body: nil))
        try! sut.put(2, at: "2", fts: FTSDocument(title: "Beta", subtitle: nil, body: nil))
        try! sut.put(10, at: "1", fts: FTSDocument(title: "Gamma", subtitle: nil, body: nil))

        XCTAssertEqual(try! sut.fetchAll(search: "Gamma"), [10])
    }

    func testRemove() throws {
        try sut.put(1, at: "1", fts: .init(title: "One"), secondaryIndexValues: [0: "one"])
        try sut.remove("1")

        let one: Int? = try sut.get("1")
        XCTAssertNil(one)

        let searchRecords = try db.queue.read { db in
            try KeyValueStore.FTSRecord.fetchAll(db)
        }
        XCTAssertEqual(searchRecords.isEmpty, true)

        let indexRecords = try db.queue.read { db in
            try KeyValueStore.SecondaryIndexRecord.fetchAll(db)
        }
        XCTAssertEqual(indexRecords.isEmpty, true)
    }

    func testRemoveAll() throws {
        try sut.put(1, at: "odd_1", fts: .init(title: "One"), secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "even_2", fts: .init(title: "One"), secondaryIndexValues: [0: "one"])
        try sut.put(3, at: "odd_3", fts: .init(title: "One"), secondaryIndexValues: [0: "one"])
        try sut.put(4, at: "even_4", fts: .init(title: "One"), secondaryIndexValues: [0: "one"])
        try sut.removeAll("even_")

        let records: [Int] = try sut.fetchAll()
        XCTAssertEqual(records, [1, 3])

        let searchRecords = try db.queue.read { db in
            try KeyValueStore.FTSRecord.fetchAll(db)
        }
        XCTAssertEqual(searchRecords.count, 2)

        let indexRecords = try db.queue.read { db in
            try KeyValueStore.SecondaryIndexRecord.fetchAll(db)
        }
        XCTAssertEqual(indexRecords.count, 2)
    }

    @MainActor
    func testObserve() async throws {
        Task {
            try await Task.sleep(for: .milliseconds(10))
            try sut.put(1, at: "1")
            try sut.put(1, at: "1")
            try sut.put(2, at: "1")
            try sut.put(3, at: "1")
            try sut.remove("1")
        }

        let values: [Int?] = try await Array(sut.observe("1").prefix(5))
        XCTAssertEqual(values, [nil, 1, 2, 3, nil])
    }

    func testFetchAll() throws {
        try sut.put(1, at: "1")
        try sut.put(2, at: "2")
        try sut.put(3, at: "3")
        try sut.put(4, at: "4")

        let values: [Int] = try sut.fetchAll()
        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    func testFetchAllWithPrefix() throws {
        try sut.put(1, at: "single_1")
        try sut.put(11, at: "double_1")
        try sut.put(2, at: "single_2")
        try sut.put(22, at: "double_2")
        try sut.put(3, at: "single_3")
        try sut.put(4, at: "single_4")

        let values: [Int] = try sut.fetchAll("double_")
        XCTAssertEqual(values, [11, 22])
    }

    func testFetchAllSecondaryIndex() throws {
        try sut.put(1, at: "1", secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "4", secondaryIndexValues: [0: "four"])

        let values: [Int] = try sut.fetchAll(order: [.init(index: 0, ascending: true)])
        XCTAssertEqual(values, [4, 1, 3, 2])
    }

    func testFetchAllSecondaryIndexWithKeyPrefix() throws {
        try sut.put(1, at: "odd_1", secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "even_2", secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "odd_3", secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "even_4", secondaryIndexValues: [0: "four"])

        let values: [Int] = try sut.fetchAll("even_", order: [.init(index: 0, ascending: true)])
        XCTAssertEqual(values, [4, 2])
    }

    func testFetchAllSecondaryIndexWithRange() throws {
        try sut.put(1, at: "1", secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "4", secondaryIndexValues: [0: "four"])

        let values: [Int] = try sut.fetchAll(order: [.init(index: 0, ascending: true)], range: 1..<3)
        XCTAssertEqual(values, [1, 3])
    }

    func testFetchAllSecondaryIndexNonexisting() throws {
        try sut.put(1, at: "1", secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "4", secondaryIndexValues: [0: "four"])

        let values: [Int] = try sut.fetchAll(order: [.init(index: 1, ascending: true)])
        XCTAssertEqual(values, [])
    }

    func testUpdateSecondaryIndex() throws {
        try sut.put(1, at: "1", secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "4", secondaryIndexValues: [0: "four"])

        // update 2 to make it the first instead of last
        try sut.put(2, at: "2", secondaryIndexValues: [0: "aaa"])

        let values: [Int] = try sut.fetchAll(order: [.init(index: 0, ascending: true)])
        XCTAssertEqual(values, [2, 4, 1, 3])
    }

    func testFetchAllFilterSingle() throws {
        try sut.put(4, at: "4", secondaryIndexValues: [0: "a"])
        try sut.put(1, at: "1", secondaryIndexValues: [0: "a"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "b"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "c"])

        let values: [Int] = try sut.fetchAll(filters: [.init(index: 0, condition: .greaterThanOrEqualTo("b"))])
        XCTAssertEqual(values, [2, 3])
    }

    func testFetchAllFilterMultiple() throws {
        try sut.put(4, at: "4", secondaryIndexValues: [0: "a", 1: "c"])
        try sut.put(1, at: "1", secondaryIndexValues: [0: "a", 1: "d"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "b", 1: "c"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "b", 1: "d"])

        let values: [Int] = try sut.fetchAll(filters: [
            .init(index: 0, condition: .greaterThanOrEqualTo("b")),
            .init(index: 1, condition: .lessThanOrEqualTo("c"))
        ])
        XCTAssertEqual(values, [3])
    }

    func testFetchAllSecondaryIndexKeyTieBreaker() throws {
        try sut.put(4, at: "4", secondaryIndexValues: [0: "a"])
        try sut.put(1, at: "1", secondaryIndexValues: [0: "a"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "a"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "a"])

        let values: [Int] = try sut.fetchAll(order: [.init(index: 0, ascending: true)])
        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    func testFetchAllSecondaryIndexRemovedEntries() throws {
        try sut.put(1, at: "1", secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "2", secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "3", secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "4", secondaryIndexValues: [0: "four"])

        try sut.remove("2")
        try sut.remove("4")

        let values: [Int] = try sut.fetchAll(order: [.init(index: 0, ascending: true)])
        XCTAssertEqual(values, [1, 3])
    }

    func testFetchAllWithSearchAndSecondaryIndex() throws {
        try sut.put(1, at: "1", fts: .init(title: "Odd One"), secondaryIndexValues: [0: "one"])
        try sut.put(2, at: "2", fts: .init(title: "Even Two"), secondaryIndexValues: [0: "two"])
        try sut.put(3, at: "3", fts: .init(title: "Odd Three"), secondaryIndexValues: [0: "three"])
        try sut.put(4, at: "4", fts: .init(title: "Even Four"), secondaryIndexValues: [0: "four"])

        let values: [Int] = try sut.fetchAll(search: "Ev", order: [.init(index: 0, ascending: true)])
        XCTAssertEqual(values, [4, 2])
    }

}
