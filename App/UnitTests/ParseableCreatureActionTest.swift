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
@testable import GameModels
import Helpers

class ParseableCreatureActionTest: XCTestCase {

    func testRecharge() {
        let action = CreatureAction(id: UUID(), name: "Web (Recharge 5-6)", description: "Ranged Weapon Attack: +5 to hit, range 30/60 ft., one creature. Hit: The target is restrained by webbing. As an action, the restrained target can make a DC 12 Strength check, bursting the webbing on a success. The webbing can also be attacked and destroyed (AC 10; hp 5; vulnerability to fire damage; immunity to bludgeoning, poison, and psychic damage).")

        var sut = ParseableCreatureAction(input: action)
        _ = sut.parseIfNeeded()

        let expectedLimitedUse = Located(
            value: LimitedUse(amount: 1, recharge: .turnStart([5, 6])),
            range: 5..<17
        )
        expectNoDifference(sut.result?.value?.limitedUse, expectedLimitedUse)
    }

    func testSpellcastingActionAddsSpellReferences() {
        let action = CreatureAction(
            id: UUID(),
            name: "Spellcasting",
            description: "The dragon casts one of the following spells, requiring no Material components and using Charisma as the spellcasting ability (spell save DC 17, +9 to hit with spell attacks): - At Will: Detect Magic, Fear, Acid Arrow - 1e/Day Each: Speak with Dead, Vitriolic Sphere"
        )

        var sut = ParseableCreatureAction(input: action)
        _ = sut.parseIfNeeded()

        let spellReferences = sut.result?.value?.descriptionAnnotations.compactMap { located -> String? in
            guard case .reference(.compendiumItem(let reference)) = located.value else { return nil }
            return reference.text
        }

        expectNoDifference(
            spellReferences,
            ["detect magic", "fear", "acid arrow", "speak with dead", "vitriolic sphere"]
        )
    }

}
