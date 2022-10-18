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
        dataSource = FileDataSource(path: defaultMonstersPath)
    }

    func test() async throws {
        let sut = Open5eMonsterDataSourceReader(dataSource: dataSource)
        let job = sut.makeJob()

        let items = try await Array(job.output.compactMap { $0.item })
        assertSnapshot(matching: items, as: .dump)
    }

}
