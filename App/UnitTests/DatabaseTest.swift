//
//  DatabaseTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import Persistence

class DatabaseTest: XCTestCase {

    func testInitialization() {
        measure {
            let _ = try! Database(path: nil)
        }
    }

}
