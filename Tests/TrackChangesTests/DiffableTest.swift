//
//  DiffableTest.swift
//  
//
//  Created by Thomas Visser on 01/02/2023.
//
import Foundation
import XCTest
import TrackChanges
import CustomDump
import Helpers

final class DiffableTest: XCTestCase {

    func testDifferenceTopLevelValues() throws {
        let a = User(name: "Alex", age: 11)
        let b = User(name: "Bob", age: 22)

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["name"], action: .set(from: "Alex")),
            Change(path: ["age"], action: .set(from: 11))
        ])
    }

    func testDifferenceTopLevelOptionalValues() throws {
        let a = User(name: "Alex", age: 11, company: User.Company(name: "Corp"), address: nil)
        let b = User(name: "Alex", age: 11, company: nil, address: User.Address(street: "Main Street", houseNumber: 11))

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["company"], action: .set(from: User.Company(name: "Corp"))),
            Change(path: ["address"], action: .set(from: Optional<User.Address>.none)),
        ])
    }

    func testDifferenceNestedValues() throws {
        let a = User(name: "Alex", age: 11, company: User.Company(name: "Corp"))
        let b = apply(a) { $0.company?.name = "Corp Inc." }

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["company", "name"], action: .set(from: "Corp"))
        ])
    }

    func testDifferenceCollectionWithValuesNoChanges() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [1, 2, 3])

        XCTAssertNoDifference(try b.difference(from: a), [])
    }

    func testDifferenceCollectionWithValuesInsertionBegin() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [0, 1, 2, 3])

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["numbers"], action: .insert(offset: 0))
        ])
    }

    func testDifferenceCollectionWithValuesInsertionEnd() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [1, 2, 3, 0])

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["numbers"], action: .insert(offset: 3))
        ])
    }

    func testDifferenceCollectionWithValuesRemovalBegin() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [2, 3])

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["numbers"], action: .remove(offset: 0, value: 1))
        ])
    }

    func testDifferenceCollectionWithValuesRemovalEnd() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [1, 2])

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["numbers"], action: .remove(offset: 2, value: 3))
        ])
    }

    func testDifferenceCollectionWithValuesAllChanged() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [4, 5, 6])

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["numbers"], action: .remove(offset: 0, value: 1)),
            Change(path: ["numbers"], action: .insert(offset: 0)),
            Change(path: ["numbers"], action: .remove(offset: 1, value: 2)),
            Change(path: ["numbers"], action: .insert(offset: 1)),
            Change(path: ["numbers"], action: .remove(offset: 2, value: 3)),
            Change(path: ["numbers"], action: .insert(offset: 2))
        ])
    }

    func testDifferenceCollectionWithValuesMixed() throws {
        let a = User(name: "Alex", age: 11, numbers: [1, 2, 3])
        let b = User(name: "Alex", age: 11, numbers: [0, 2, 2, 4])

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["numbers"], action: .remove(offset: 0, value: 1)),
            Change(path: ["numbers"], action: .insert(offset: 0)),
            Change(path: ["numbers"], action: .remove(offset: 2, value: 3)),
            Change(path: ["numbers"], action: .insert(offset: 2)),
            Change(path: ["numbers"], action: .insert(offset: 3))
        ])
    }

    func testDifferenceCollectionWithIdentifiableDiffables() throws {
        let a = User(name: "Alex", age: 10, friends: [
            User(name: "John", age: 11),
            User(name: "Frank", age: 11),
        ])
        let b = apply(a) { $0.friends[0].age = 12 }

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["friends", "0", "age"], action: .set(from: 11))
        ])
    }

    func testDifferenceCollectionWithIdentifiableDiffablesAndInsertionBegin() throws {
        let a = User(name: "Alex", age: 10, friends: [
            User(name: "Frank", age: 11)
        ])
        let b = apply(a) {
            $0.friends.insert(User(name: "John", age: 13), at: 0)
            $0.friends[1].age = 12
        }

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["friends"], action: .insert(offset: 0)),
            Change(path: ["friends", "1", "age"], action: .set(from: 11))
        ])
    }

    func testDifferenceCollectionWithIdentifiableDiffablesAndRemovalBegin() throws {
        let a = User(name: "Alex", age: 10, friends: [
            User(name: "Frank", age: 11),
            User(name: "John", age: 13)
        ])
        let b = apply(a) {
            $0.friends.remove(at: 0)
            $0.friends[0].age = 12
        }

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["friends"], action: .remove(offset: 0, value: User(name: "Frank", age: 11))),
            Change(path: ["friends", "0", "age"], action: .set(from: 13))
        ])
    }

    func testDifferenceDictionary() throws {
        let a = User(name: "Alex", age: 10, custom: ["a": "aa", "b": "bb", "c": "cc"])
        let b = apply(a) {
            $0.custom["a"] = nil
            $0.custom["c"] = "ccc"
            $0.custom["d"] = "ddd"
        }

        XCTAssertNoDifference(try b.difference(from: a), [
            Change(path: ["custom", "a"], action: .set(from: "aa")),
            Change(path: ["custom", "c"], action: .set(from: "cc")),
            Change(path: ["custom", "d"], action: .set(from: Optional<String>.none)),
        ])
    }

}

struct User: Codable, Equatable, Diffable {
    var name: String
    var age: Int
    var company: Company?
    var address: Address? // not Diffable
    var numbers: [Int] = []
    var friends: [User] = []
    var custom: [String: String] = [:]

    struct Company: Equatable, Codable, Diffable {
        var name: String
    }

    struct Address: Equatable, Codable { // not diffable on purpose
        var street: String
        var houseNumber: Int
    }
}

//extension User: Diffable {
//    static var diffableKeys = ["name", "age", "company", "address", "numbers", "friends", "custom"]
//
//    func value(forDiffableKey key: String) throws -> Any {
//        switch key {
//        case "name": return name
//        case "age": return age
//        case "company": return company as Any
//        case "address": return address as Any
//        case "numbers": return numbers
//        case "friends": return friends
//        case "custom": return custom
//        default: throw DiffableError()
//        }
//    }
//}
//
//extension User.Company: Diffable {
//    static var diffableKeys = ["name"]
//    func value(forDiffableKey key: String) throws -> Any {
//        switch key {
//        case "name": return name
//        default: throw DiffableError()
//        }
//    }
//}

extension User: Identifiable {
    var id: String { name }
}
