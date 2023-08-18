//
//  CompendiumEntryTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 28/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import GameModels
@testable import Construct
@testable import Persistence

class CompendiumEntryTest: XCTestCase {
    func testKey() {
        let itemKey = CompendiumItemKey(type: .character, realm: .init(CompendiumRealm.core.id), identifier: "123")
        let entryKey = CompendiumEntry.key(for: itemKey)
        XCTAssertEqual(itemKey, CompendiumItemKey(compendiumEntryKey: entryKey.rawValue))
    }
}
