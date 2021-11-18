//
//  ParseableCreatureFeatureTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 17/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import CustomDump
@testable import Construct

class ParseableCreatureFeatureTest: XCTestCase {

    func test() {
        let feature = CreatureFeature(name: "Spellcasting", description: "The acolyte is a 1st-level spellcaster. Its spellcasting ability is Wisdom (spell save DC 12, +4 to hit with spell attacks). The acolyte has following cleric spells prepared:\n\n• Cantrips (at will): light, sacred flame, thaumaturgy\n• 1st level (3 slots): bless, cure wounds, sanctuary")

        var sut = ParseableCreatureFeature(input: feature)
        sut.parseIfNeeded()

        let expected = ParsedCreatureFeature.spellcasting(.init(
            innate: false,
            spellcasterLevel: 1,
            ability: .wisdom,
            spellSaveDC: 12,
            spellAttackHit: Modifier(modifier: 4),
            slotsByLevel: [1: 3],
            spellsByLevel: [
                0: [
                    Located(value: "light", range: 198..<203),
                    Located(value: "sacred flame", range: 205..<217),
                    Located(value: "thaumaturgy", range: 219..<230),
                ],
                1: [
                    Located(value: "bless", range: 254..<259),
                    Located(value: "cure wounds", range: 261..<272),
                    Located(value: "sanctuary", range: 274..<283),
                ]
            ],
            spellsPerDay: nil,
            freeform: ParsedCreatureFeature.Freeform(
                expressions: [
                    Located(value: 1.d(20)+4, range: 94..<96)
                ]
            )
        ))
        XCTAssertNoDifference(sut.result?.value, expected)
    }
}
