//
//  File.swift
//  
//
//  Created by Thomas Visser on 03/02/2023.
//

import Foundation
import XCTest
import TrackChanges
import CustomDump

final class TrackedTest: XCTestCase {

    func testChange() throws {
        var sut = Tracked(Counter())
        try sut.change {
            $0.count += 1
        }
        try sut.change {
            $0.count = 42
        }

        XCTAssertNoDifference(sut.wrapped, Counter(count: 42))
        XCTAssertEqual(sut.history.count, 2)
    }

    func testSet() throws {
        var sut = Tracked(Counter())
        try sut.set(newValue: Counter(count: 1), message: "first")
        try sut.set(newValue: Counter(count: 42), message: "second")

        XCTAssertNoDifference(sut.wrapped, Counter(count: 42))
        XCTAssertEqual(sut.history.count, 2)
        XCTAssertEqual(sut.history[0].set.message, "second")
        XCTAssertEqual(sut.history[1].set.message, "first")
    }

    func testUndo() throws {
        var sut = Tracked(Counter())

        XCTAssertFalse(sut.canUndo())
        XCTAssertThrowsError(try sut.undo())

        try sut.set(newValue: Counter(count: 1), message: "first")
        XCTAssertTrue(sut.canUndo())
        try sut.undo()

        XCTAssertFalse(sut.canUndo())
        XCTAssertThrowsError(try sut.undo())

        XCTAssertNoDifference(sut.wrapped, Counter())
        XCTAssertEqual(sut.history.count, 2)
        XCTAssertEqual(sut.history[0].set.message, nil)
        XCTAssertEqual(sut.history[1].set.message, "first")
    }

    func testRedo() throws {
        var sut = Tracked(Counter())

        XCTAssertFalse(sut.canRedo())
        XCTAssertThrowsError(try sut.redo())

        try sut.set(newValue: Counter(count: 1), message: "first")
        XCTAssertFalse(sut.canRedo())
        XCTAssertThrowsError(try sut.redo())

        try sut.undo()

        XCTAssertTrue(sut.canRedo())
        try sut.redo()

        XCTAssertFalse(sut.canRedo())
        XCTAssertThrowsError(try sut.redo())

        XCTAssertNoDifference(sut.wrapped, Counter(count: 1))
        XCTAssertEqual(sut.history.count, 1)
        XCTAssertEqual(sut.history[0].set.message, "first")
    }

    func testChangeSetBaseHash() throws {
        var sut = Tracked(Counter())

        try sut.set(newValue: Counter(count: 1), message: "first")
        // hash for count == 0
        XCTAssertNoDifference(sut.history.first?.set.baseHash, "b6589fc6ab0dc82cf12099d1c2d40ab994e8410c")

        try sut.set(newValue: Counter(count: 1), message: "second")
        // hash for count == 1
        XCTAssertNoDifference(sut.history.first?.set.baseHash, "356a192b7913b04c54574d18c28d46e6395428ab")

        try sut.set(newValue: Counter(count: 2), message: "third")
        // hash for count == 1
        XCTAssertNoDifference(sut.history.first?.set.baseHash, "356a192b7913b04c54574d18c28d46e6395428ab")
    }

    func testTrackedChangesPerformance() throws {
        var sut = Tracked(Counter())
        measure {
            for _ in 0..<1000 {
                try! sut.change {
                    $0.count += 1
                }
            }
        }
    }

    func testBaseline() throws {
        var sut = Counter()
        measure {
            for _ in 0..<1000 {
                sut.count += 1
            }
        }
    }

}

struct Counter: Diffable, Patchable, Equatable {
    var count: Int = 0
}
