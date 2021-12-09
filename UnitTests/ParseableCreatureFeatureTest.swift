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

    func testSpellcasting() {
        let feature = CreatureFeature(name: "Spellcasting", description: "The acolyte is a 1st-level spellcaster. Its spellcasting ability is Wisdom (spell save DC 12, +4 to hit with spell attacks). The acolyte has following cleric spells prepared:\n\n• Cantrips (at will): light, sacred flame, thaumaturgy\n• 1st level (3 slots): bless, cure wounds, sanctuary")

        var sut = ParseableCreatureFeature(input: feature)
        sut.parseIfNeeded()

        let expected = ParsedCreatureFeature(
            limitedUse: nil,
            spellcasting: ParsedCreatureFeature.Spellcasting(
                innate: false,
                spellcasterLevel: 1,
                ability: .wisdom,
                spellSaveDC: 12,
                spellAttackHit: Modifier(modifier: 4),
                slotsByLevel: [1: 3],
                spellsByLevel: [
                    0: [Located(value: .init(text: "light", type: .spell, resolvedTo: nil), range: 198..<203),
                        Located(value: .init(text: "sacred flame", type: .spell, resolvedTo: nil), range: 205..<217),
                        Located(value: .init(text: "thaumaturgy", type: .spell, resolvedTo: nil), range: 219..<230),
                    ],
                    1: [
                        Located(value: .init(text: "bless", type: .spell, resolvedTo: nil), range: 254..<259),
                        Located(value: .init(text: "cure wounds", type: .spell, resolvedTo: nil), range: 261..<272),
                        Located(value: .init(text: "sanctuary", type: .spell, resolvedTo: nil), range: 274..<283),
                    ]
                ],
                limitedUseSpells: nil
            ),
            otherDescriptionAnnotations: [
                Located(value: .diceExpression(1.d(20)+4), range: 94..<96)
            ]
        )

        XCTAssertNoDifference(sut.result?.value, expected)
    }

    func testInnateSpellcasting() {
        let feature = CreatureFeature(name: "Innate Spellcasting", description: "The giant's innate spellcasting ability is Charisma. It can innately cast the following spells, requiring no material components:\n\nAt will: detect magic, fog cloud, light\n3/day each: feather fall, fly, misty step, telekinesis\n1/day each: control weather, gaseous form")

        var sut = ParseableCreatureFeature(input: feature)
        sut.parseIfNeeded()

        let expected = ParsedCreatureFeature(
            limitedUse: nil,
            spellcasting: ParsedCreatureFeature.Spellcasting(
                innate: true,
                spellcasterLevel: nil,
                ability: .charisma,
                spellSaveDC: nil,
                spellAttackHit: nil,
                slotsByLevel: nil,
                spellsByLevel: nil,
                limitedUseSpells: [
                    .init(spells: [Located(value: .init(text: "detect magic", type: .spell, resolvedTo: nil), range: 140..<152)], limitedUse: nil),
                    .init(spells: [Located(value: .init(text: "fog cloud", type: .spell, resolvedTo: nil), range: 154..<163)], limitedUse: nil),
                    .init(spells: [Located(value: .init(text: "light", type: .spell, resolvedTo: nil), range: 165..<170)], limitedUse: nil),
                    .init(spells: [Located(value: .init(text: "feather fall", type: .spell, resolvedTo: nil), range: 183..<195)], limitedUse: .init(amount: 3, recharge: .day)),
                    .init(spells: [Located(value: .init(text: "fly", type: .spell, resolvedTo: nil), range: 197..<200)], limitedUse: .init(amount: 3, recharge: .day)),
                    .init(spells: [Located(value: .init(text: "misty step", type: .spell, resolvedTo: nil), range: 202..<212)], limitedUse: .init(amount: 3, recharge: .day)),
                    .init(spells: [Located(value: .init(text: "telekinesis", type: .spell, resolvedTo: nil), range: 214..<225)], limitedUse: .init(amount: 3, recharge: .day)),
                    .init(spells: [Located(value: .init(text: "control weather", type: .spell, resolvedTo: nil), range: 238..<253)], limitedUse: .init(amount: 1, recharge: .day)),
                    .init(spells: [Located(value: .init(text: "gaseous form", type: .spell, resolvedTo: nil), range: 255..<267)], limitedUse: .init(amount: 1, recharge: .day))
                ]
            ),
            otherDescriptionAnnotations: []
        )

        XCTAssertNoDifference(sut.result?.value, expected)
    }
}
