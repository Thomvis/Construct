//
//  CreatureEditViewStateTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 17/06/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import GameModels

class CreatureEditViewStateTest: XCTestCase {

    func testCharacterStability() {
        let character = GameModels.Character(id: UUID().tagged(), realm: .init(CompendiumRealm.homebrew.id), level: nil, stats: StatBlock.default, player: nil)
        let sut = CreatureEditViewState(edit: character)
        XCTAssertEqual(character, sut.character)
    }
    
}
