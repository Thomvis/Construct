//
//  KeyValueStoreTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
@testable import Persistence
import GRDB

class KeyValueStoreTest: XCTestCase {
    var sut: KeyValueStore!

    override func setUp() {
        super.setUp()
        let database = try! Database(path: nil, importDefaultContent: false)
        self.sut = database.keyValueStore
    }

    func testPutAndGet() {
        try! sut.put(1, at: "1")
        XCTAssertEqual(try! sut.get("1"), 1)
    }

    func testFTS() {
        try! sut.put(1, at: "1", fts: FTSDocument(title: "Alpha", subtitle: nil, body: nil))
        try! sut.put(2, at: "2", fts: FTSDocument(title: "Beta", subtitle: nil, body: nil))

        XCTAssertEqual(try! sut.match("al*"), [1])
    }

    func testOverwrite() {
        try! sut.put(1, at: "1")
        try! sut.put(11, at: "1")

        XCTAssertEqual(try! sut.get("1"), 11)
    }

    func testOverwriteWithFTS() {
        try! sut.put(1, at: "1", fts: FTSDocument(title: "Alpha", subtitle: nil, body: nil))
        try! sut.put(11, at: "1", fts: FTSDocument(title: "Omega", subtitle: nil, body: nil))

        XCTAssertEqual(try! sut.match("Omega"), [11])
    }

    func testUpdateOfNonLastRowFTS() {
        try! sut.put(1, at: "1", fts: FTSDocument(title: "Alpha", subtitle: nil, body: nil))
        try! sut.put(2, at: "2", fts: FTSDocument(title: "Beta", subtitle: nil, body: nil))
        try! sut.put(10, at: "1", fts: FTSDocument(title: "Gamma", subtitle: nil, body: nil))

        XCTAssertEqual(try! sut.match("Gamma"), [10])
    }

}
