//
//  Open5eMonsterDataSourceReaderTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine
import SnapshotTesting
import Compendium

class Open5eMonsterDataSourceReaderTest: XCTestCase {

    var dataSource: CompendiumDataSource!

    override func setUp() {
        dataSource = FileDataSource(path: Bundle.main.path(forResource: "monsters", ofType: "json")!)
    }

    func test() {
        let sut = Open5eMonsterDataSourceReader(dataSource: dataSource)
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.output.compactMap { $0.item }.collect().sink(receiveCompletion: { _ in
            e.fulfill()
        }, receiveValue: { items in
            assertSnapshot(matching: items, as: .dump)
        })

        waitForExpectations(timeout: 2.0, handler: nil)
    }

}
