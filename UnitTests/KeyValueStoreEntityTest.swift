//
//  KeyValueStoreEntityTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct

class KeyValueStoreEntityTest: XCTestCase {

    func testEnsureUniquePrefixes() {
        for i1 in KeyValueStoreEntityKeyPrefix.allCases.indices {
            let p1 = KeyValueStoreEntityKeyPrefix.allCases[i1]
            for i2 in KeyValueStoreEntityKeyPrefix.allCases.indices {
                guard i1 != i2 else { continue }
                let p2 = KeyValueStoreEntityKeyPrefix.allCases[i2]
                XCTAssertFalse(p1.rawValue.hasPrefix(p2.rawValue), "\(p2) is a prefix of \(p1)")
            }
        }
    }

    func testEnsureKeyPrefixTypeConsistency() {
        for p in KeyValueStoreEntityKeyPrefix.allCases {
            XCTAssertEqual(p.entityType.keyPrefix, p)
        }
    }

}
