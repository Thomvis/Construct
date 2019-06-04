//
//  AlignmentTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 15/04/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct

class AlignmentTest: XCTestCase {
    func testCodable() {
        assertCodableSymmetry(Alignment.unaligned)
        assertCodableSymmetry(Alignment.any)
        assertCodableSymmetry(Alignment.moral(.chaotic))
        assertCodableSymmetry(Alignment.ethic(.neutral))
        assertCodableSymmetry(Alignment.both(.lawful, .evil))
        assertCodableSymmetry(Alignment.inverse(.any))
        assertCodableSymmetry(Alignment.inverse(.moral(.neutral)))
        assertCodableSymmetry(Alignment.inverse(.both(.lawful, .neutral)))
    }

    private func assertCodableSymmetry<V>(_ value: V, _ file: StaticString = #file, _ line: UInt = #line) where V: Codable, V: Equatable {
        XCTAssertEqual(value, try? JSONDecoder().decode(V.self, from: JSONEncoder().encode(value)))
    }
}
