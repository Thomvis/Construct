//
//  DndBeyondExternalCompendiumTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 30/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import CustomDump
@testable import Construct

class DndBeyondExternalCompendiumTest: XCTestCase {

    func testSearchPageUrl() {
        let sut = DndBeyondExternalCompendium()
        XCTAssertEqual("https://www.dndbeyond.com/search?q=tasha's%20hideous%20laughter", sut.searchPageUrl(for: "tasha's hideous laughter").absoluteString)
    }

    func testUrlForReferenceAnnotation() {
        let sut = DndBeyondExternalCompendium()
        XCTAssertEqual(
            "https://www.dndbeyond.com/spells/tashas-hideous-laughter",
            sut.url(for: CompendiumItemReferenceTextAnnotation(
                text: "Tasha's Hideous Laughter ",
                type: .spell
            ))?.absoluteString
        )
    }

}
