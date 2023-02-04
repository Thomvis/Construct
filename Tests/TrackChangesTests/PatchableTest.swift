//
//  File.swift
//  
//
//  Created by Thomas Visser on 02/02/2023.
//

import Foundation
import XCTest
import TrackChanges
import CustomDump
import Helpers

final class PatchableTest: XCTestCase {

    func testRollbackTopLevelValues() throws {
        var sut = User(name: "Bob", age: 22)
        try sut.rollback(Change(
            path: ["name"],
            action: .set(from: "Alex"))
        )

        try sut.rollback(Change(
            path: ["age"],
            action: .set(from: 11))
        )
        XCTAssertNoDifference(sut, User(name: "Alex", age: 11))
    }

    func testRollbackTopLevelOptionalValues() throws {
        var sut = User(name: "Alex", age: 11, company: nil, address: User.Address(street: "Main Street", houseNumber: 11))

        try sut.rollback(Change(path: ["company"], action: .set(from: User.Company(name: "Corp"))))
        try sut.rollback(Change(path: ["address"], action: .set(from: Optional<User.Address>.none)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, company: User.Company(name: "Corp"), address: nil))
    }

    func testRollbackNestedValues() throws {
        var sut = User(name: "Alex", age: 11, company: User.Company(name: "Corp Inc."))
        try sut.rollback(Change(path: ["company", "name"], action: .set(from: "Corp")))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, company: User.Company(name: "Corp")))
    }

    func testRollbackCollectionWithValuesInsertionBegin() throws {
        var sut = User(name: "Alex", age: 11, numbers: [0, 1, 2, 3])

        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 0)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, numbers: [1, 2, 3]))
    }

    func testRollbackCollectionWithValuesInsertionEnd() throws {
        var sut = User(name: "Alex", age: 11, numbers: [1, 2, 3, 0])

        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 3)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, numbers: [1, 2, 3]))
    }

    func testRollbackCollectionWithValuesRemovalBegin() throws {
        var sut = User(name: "Alex", age: 11, numbers: [2, 3])

        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 0, value: 1)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, numbers: [1, 2, 3]))
    }

    func testRollbackCollectionWithValuesRemovalEnd() throws {
        var sut = User(name: "Alex", age: 11, numbers: [1, 2])

        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 2, value: 3)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, numbers: [1, 2, 3]))
    }

    func testRollbaclCollectionWithValuesAllChanged() throws {
        var sut = User(name: "Alex", age: 11, numbers: [4, 5, 6])

        // note: the action order is reversed
        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 2)))
        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 2, value: 3)))
        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 1)))
        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 1, value: 2)))
        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 0)))
        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 0, value: 1)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, numbers: [1, 2, 3]))
    }

    func testRollbackCollectionWithValuesMixed() throws {
        var sut = User(name: "Alex", age: 11, numbers: [0, 2, 2, 4])

        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 3)))
        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 2)))
        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 2, value: 3)))
        try sut.rollback(Change(path: ["numbers"], action: .insert(offset: 0)))
        try sut.rollback(Change(path: ["numbers"], action: .remove(offset: 0, value: 1)))

        XCTAssertNoDifference(sut, User(name: "Alex", age: 11, numbers: [1, 2, 3]))
    }

    func testRollbackCollectionWithIdentifiableDiffables() throws {
        let a = User(name: "Alex", age: 10, friends: [
            User(name: "John", age: 11),
            User(name: "Frank", age: 11),
        ])
        var sut = apply(a) { $0.friends[0].age = 12 }

        try sut.rollback(Change(path: ["friends", "0", "age"], action: .set(from: 11)))

        XCTAssertNoDifference(sut, a)
    }

    func testRollbackCollectionWithIdentifiableDiffablesAndInsertionBegin() throws {
        let a = User(name: "Alex", age: 10, friends: [
            User(name: "Frank", age: 11)
        ])
        var sut = apply(a) {
            $0.friends.insert(User(name: "John", age: 13), at: 0)
            $0.friends[1].age = 12
        }

        try sut.rollback(Change(path: ["friends", "1", "age"], action: .set(from: 11)))
        try sut.rollback(Change(path: ["friends"], action: .insert(offset: 0)))

        XCTAssertNoDifference(sut, a)
    }

    func testRollbackCollectionWithIdentifiableDiffablesAndRemovalBegin() throws {
        let a = User(name: "Alex", age: 10, friends: [
            User(name: "Frank", age: 11),
            User(name: "John", age: 13)
        ])
        var sut = apply(a) {
            $0.friends.remove(at: 0)
            $0.friends[0].age = 12
        }

        try sut.rollback(Change(path: ["friends", "0", "age"], action: .set(from: 13)))
        try sut.rollback(Change(path: ["friends"], action: .remove(offset: 0, value: User(name: "Frank", age: 11))))

        XCTAssertNoDifference(sut, a)
    }

    func testRollbackDictionary() throws {
        let a = User(name: "Alex", age: 10, custom: ["a": "aa", "b": "bb", "c": "cc"])
        var sut = apply(a) {
            $0.custom["a"] = nil
            $0.custom["c"] = "ccc"
            $0.custom["d"] = "ddd"
        }

        try sut.rollback(Change(path: ["custom", "d"], action: .set(from: Optional<String>.none)))
        try sut.rollback(Change(path: ["custom", "c"], action: .set(from: "cc")))
        try sut.rollback(Change(path: ["custom", "a"], action: .set(from: "aa")))

        XCTAssertNoDifference(sut, a)
    }

}

extension User: Patchable { }
extension User.Company: Patchable { }
