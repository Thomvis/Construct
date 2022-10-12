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

//class XMLCompendiumDataSourceReaderTest: XCTestCase {
//
//    func test() {
//        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "compendium", ofType: "xml")!)
//        let sut = XMLCompendiumDataSourceReader(dataSource: dataSource)
//        let job = sut.read()
//
//        let e = expectation(description: "Receive items")
//        _ = job.output.compactMap { $0.item }.collect().sink(receiveCompletion: { c in
//            if case .failure(let e) = c {
//                XCTFail(e.localizedDescription)
//            }
//        }) { items in
//            assertSnapshot(matching: items, as: .dump)
//            e.fulfill()
//        }
//
//        waitForExpectations(timeout: 2.0, handler: nil)
//    }
//
//    func testIncorrectFormat() {
//        let dataSource = FileDataSource(path: Bundle(for: Self.self).path(forResource: "ii_mm", ofType: "json")!)
//        let sut = XMLCompendiumDataSourceReader(dataSource: dataSource)
//        let job = sut.read()
//
//        let e = expectation(description: "Receive items")
//        _ = job.output.compactMap { $0.item }.collect().sink(receiveCompletion: { c in
//            guard case .failure(.incompatibleDataSource) = c else { XCTFail(); return }
//            e.fulfill()
//        }, receiveValue: { _ in })
//
//        waitForExpectations(timeout: 2.0, handler: nil)
//    }
//
//}
