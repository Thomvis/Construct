// Generated using Sourcery 1.6.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
import TrackChanges

/// Generated `Diffable` implementations
import Foundation
import XCTest
import TrackChanges
import CustomDump
extension Counter {
	internal static var diffableKeys = ["count", ]

	internal func value(forDiffableKey key: String) throws -> Any {
		switch key {
		case "count": return count as Any
		default: throw DiffableError()
		}
	}
}

import Foundation
import XCTest
import TrackChanges
import CustomDump
import Helpers
extension User {
	internal static var diffableKeys = ["name", "age", "company", "address", "numbers", "friends", "custom", ]

	internal func value(forDiffableKey key: String) throws -> Any {
		switch key {
		case "name": return name as Any
		case "age": return age as Any
		case "company": return company as Any
		case "address": return address as Any
		case "numbers": return numbers as Any
		case "friends": return friends as Any
		case "custom": return custom as Any
		default: throw DiffableError()
		}
	}
}

import Foundation
import XCTest
import TrackChanges
import CustomDump
import Helpers
extension User.Company {
	internal static var diffableKeys = ["name", ]

	internal func value(forDiffableKey key: String) throws -> Any {
		switch key {
		case "name": return name as Any
		default: throw DiffableError()
		}
	}
}


/// Generated `Patchable` implementations

import Foundation
import XCTest
import TrackChanges
import CustomDump
extension Counter {
	internal mutating func setValue(_ value: Any, forDiffableKey key: String) throws {
		switch (key, value) {
		case ("count", let v as Int): count = v
		default: throw PatchableError()
		}
	}
}

import Foundation
import XCTest
import TrackChanges
import CustomDump
import Helpers
extension User {
	internal mutating func setValue(_ value: Any, forDiffableKey key: String) throws {
		switch (key, value) {
		case ("name", let v as String): name = v
		case ("age", let v as Int): age = v
		case ("company", let v as Company?): company = v
		case ("address", let v as Address?): address = v
		case ("numbers", let v as [Int]): numbers = v
		case ("friends", let v as [User]): friends = v
		case ("custom", let v as [String: String]): custom = v
		default: throw PatchableError()
		}
	}
}

import Foundation
import XCTest
import TrackChanges
import CustomDump
import Helpers
extension User.Company {
	internal mutating func setValue(_ value: Any, forDiffableKey key: String) throws {
		switch (key, value) {
		case ("name", let v as String): name = v
		default: throw PatchableError()
		}
	}
}

