//
//  EncounterCombatantsDescriptionTest.swift
//  
//
//  Created by Thomas Visser on 30/12/2022.
//

import Foundation
import XCTest
import MechMuse
import GameModels

final class EncounterCombatantsTraitsTest: XCTestCase {

    func testPrompt() {
        let request = GenerateCombatantTraitsRequest(combatantNames: ["Goblin 1", "Goblin 2", "Bugbear 1"])
        XCTAssertEqual(request.prompt(toneOfVoice: .gritty), """
        A Dungeons & Dragons encounter has the following monsters: Goblin 1, Goblin 2, Bugbear 1. Come up with physical and personality traits and a fitting nickname, without interfering with its stats.

        Format your answer as correct YAML dictionary, using fields Physical, Personality, Nickname.
        """)
    }

}