//
//  StatBlockTest.swift
//  
//
//  Created by Thomas Visser on 22/11/2022.
//

import Foundation
import XCTest
import GameModels

final class StatBlockTest: XCTestCase {
    func testProficiencyInitWithModifierBaseModifierAndProficiencyBonus() {
        XCTAssertEqual(StatBlock.Proficiency(
            modifier: 4,
            base: 2,
            proficiencyBonus: 2
        ), .times(1))

        XCTAssertEqual(StatBlock.Proficiency(
            modifier: 6,
            base: 2,
            proficiencyBonus: 2
        ), .times(2))

        XCTAssertEqual(StatBlock.Proficiency(
            modifier: 3,
            base: 2,
            proficiencyBonus: 2
        ), .custom(3))
    }

    func testMakeSkillAndSaveProficienciesRelative() {
        var sut = StatBlock.default
        sut.challengeRating = 1 // +2 bonus
        sut.abilityScores = AbilityScores(
            strength: 12, // +1
            dexterity: 14, // +2
            constitution: 16, // +3
            intelligence: 15, // +2
            wisdom: 13, // +1
            charisma: 14 // +2
        )
        sut.skills[.arcana] = .custom(4) // int, so single proficiency
        sut.skills[.performance] = .custom(6) // char, so double proficiency
        sut.skills[.perception] = .custom(2) // wis, so custom

        sut.savingThrows[.strength] = .custom(5) // double proficiency
        sut.savingThrows[.constitution] = .custom(4) // custom

        sut.makeSkillAndSaveProficienciesRelative()

        XCTAssertEqual(sut.skills[.arcana], .times(1))
        XCTAssertEqual(sut.skills[.performance], .times(2))
        XCTAssertEqual(sut.skills[.perception], .custom(2))

        XCTAssertEqual(sut.savingThrows[.strength], .times(2))
        XCTAssertEqual(sut.savingThrows[.constitution], .custom(4))
    }
}
