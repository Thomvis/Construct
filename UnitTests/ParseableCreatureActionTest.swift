//
//  ParseableCreatureActionTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 22/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import CustomDump
@testable import Construct

class ParseableCreatureActionTest: XCTestCase {

    func testRecharge() {
        let action = CreatureAction(name: "Web (Recharge 5-6)", description: "Ranged Weapon Attack: +5 to hit, range 30/60 ft., one creature. Hit: The target is restrained by webbing. As an action, the restrained target can make a DC 12 Strength check, bursting the webbing on a success. The webbing can also be attacked and destroyed (AC 10; hp 5; vulnerability to fire damage; immunity to bludgeoning, poison, and psychic damage).")

        var sut = ParseableCreatureAction(input: action)
        sut.parseIfNeeded()

        let expectedLimitedUse = Located(
            value: LimitedUse(amount: 1, recharge: .turnStart([5, 6])),
            range: 5..<17
        )
        XCTAssertNoDifference(sut.result?.value?.limitedUse, expectedLimitedUse)
    }

}
