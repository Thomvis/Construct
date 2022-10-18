//
//  FileDataSourceTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import Combine
import Compendium

class FileDataSourceTest: XCTestCase {
    func test() async throws {
        let sut = FileDataSource(path: defaultMonstersPath)

        let data = try await sut.read()
        XCTAssertNotNil(data)
    }
}
