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

final class EncounterCombatantsDescriptionTest: XCTestCase {

    func testPrompt() {
        let request = EncounterCombatantsDescriptionRequest(combatantNames: ["Goblin 1", "Goblin 2", "Bugbear 1"])
        XCTAssertEqual(request.prompt(toneOfVoice: .gritty), """
        A Dungeons & Dragons encounter has the following monsters: Goblin 1, Goblin 2, Bugbear 1. Come up with unique details for each monster's appearance and behavior (in keywords) and a fitting nickname, without interfering with its stats.

        Format your answer as correct YAML dictionary, using fields appearance, behavior, nickname.
        """)
    }

}
