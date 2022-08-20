//
//  FileDataSourceTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine

class FileDataSourceTest: XCTestCase {
    func test() {
        let sut = FileDataSource(path: Bundle.main.path(forResource: "monsters", ofType: "json")!)

        let e = expectation(description: "Data is read from file")
        _ = sut.read().sink(receiveCompletion: { _ in }) { data in
            XCTAssertNotNil(data)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
}
