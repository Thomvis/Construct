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

class XMLCompendiumDataSourceReaderTest: XCTestCase {

    @MainActor
    func test() async throws {
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "compendium", ofType: "xml")!)
        let sut = XMLCompendiumDataSourceReader(dataSource: dataSource, generateUUID: UUID.fakeGenerator())
        let job = sut.makeJob()


        let items = try await Array(job.output.compactMap { $0.item })
        assertSnapshot(matching: items, as: .dump)
    }

    func testIncorrectFormat() async throws{
        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ii_mm", ofType: "json")!)
        let sut = XMLCompendiumDataSourceReader(dataSource: dataSource, generateUUID: UUID.fakeGenerator())
        let job = sut.makeJob()

        do {
            _ = try await Array(job.output)
            XCTFail("Expected job to fail")
        } catch CompendiumDataSourceReaderError.incompatibleDataSource {
            // expected
        } catch {
            XCTFail("Expected job to fail with CompendiumDataSourceReaderError.incompatibleDataSource")
        }
    }

}
