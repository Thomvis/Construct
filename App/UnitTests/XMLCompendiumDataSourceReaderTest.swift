//
//  XMLCompendiumDataSourceReaderTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 09/04/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine
import SnapshotTesting
import Compendium
import GameModels

class XMLCompendiumDataSourceReaderTest: XCTestCase {

    @MainActor
    func test() async throws {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "compendium", ofType: "xml")!)
        let sut = XMLCompendiumDataSourceReader(dataSource: dataSource, generateUUID: UUID.fakeGenerator())


        let items = try await Array(sut.items(realmId: CompendiumRealm.core.id).compactMap { $0.item })
        assertSnapshot(matching: items, as: .dump)
    }

    func testIncorrectFormat() async throws{
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ii_mm", ofType: "json")!)
        let sut = XMLCompendiumDataSourceReader(dataSource: dataSource, generateUUID: UUID.fakeGenerator())

        do {
            _ = try await Array(sut.items(realmId: CompendiumRealm.core.id))
            XCTFail("Expected job to fail")
        } catch CompendiumDataSourceReaderError.incompatibleDataSource {
            // expected
        } catch {
            XCTFail("Expected job to fail with CompendiumDataSourceReaderError.incompatibleDataSource")
        }
    }

}
