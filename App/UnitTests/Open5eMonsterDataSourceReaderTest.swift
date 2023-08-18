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
import GameModels

class Open5eMonsterDataSourceReaderTest: XCTestCase {

    var dataSource: (any CompendiumDataSource<[Open5eAPIResult]>)!

    override func setUp() {
        dataSource = FileDataSource(path: defaultMonstersPath).decode(type: [O5e.Monster].self).toOpen5eAPIResults()
    }

    @MainActor
    func test() async throws {
        let sut = Open5eDataSourceReader(dataSource: dataSource, generateUUID: UUID.fakeGenerator())

        let items = try await Array(sut.items(realmId: CompendiumRealm.core.id).compactMap { $0.item })
        assertSnapshot(matching: items, as: .dump)
    }

}
