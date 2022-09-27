//
//  CompendiumItemReferencestTe.swift
//  
//
//  Created by Thomas Visser on 28/08/2022.
//

import XCTest
import GameModels
import Helpers

final class CompendiumItemReferenceTest: XCTestCase {

    func testMigrationFromV0() throws {
        let orig = CompendiumItemReference_V0(itemTitle: "abc", itemKey: .init(rawValue: "x::monster::core::abc"))
        let data = try JSONEncoder().encode(orig)
        let sut = try JSONDecoder().decode(CompendiumItemReference.self, from: data)

        XCTAssertEqual(sut.itemTitle, orig.itemTitle)
        XCTAssertEqual(sut.itemKey.keyString, "monster::core::abc")
    }

    func testMigrationFromV1() throws {
        let orig = CompendiumItemReference_V1(itemTitle: "abc", itemKey: CompendiumItemKey(type: .monster, realm: .core, identifier: "abc"))
        let data = try JSONEncoder().encode(orig)
        let sut = try JSONDecoder().decode(CompendiumItemReference.self, from: data)

        XCTAssertEqual(sut.itemTitle, orig.itemTitle)
        XCTAssertEqual(sut.itemKey.keyString, "monster::core::abc")
    }

    // Version used until modularisation
    struct CompendiumItemReference_V0: Codable, Hashable {
        var itemTitle: String
        var itemKey: Key

        struct Key: RawRepresentable, Codable, Hashable {
            typealias RawValue = String

            let string: String

            init(rawValue: String) {
                self.string = rawValue
            }

            var rawValue: String {
                string
            }
        }
    }

    // Version used initially after modularisation (without @Migrated)
    struct CompendiumItemReference_V1: Codable, Hashable {
        var itemTitle: String
        var itemKey: CompendiumItemKey

        init(itemTitle: String, itemKey: CompendiumItemKey) {
            self.itemTitle = itemTitle
            self.itemKey = itemKey
        }
    }
}
