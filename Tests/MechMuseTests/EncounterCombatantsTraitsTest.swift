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
import CustomDump

final class EncounterCombatantsTraitsTest: XCTestCase {

    func testPrompt() {
        let request = GenerateCombatantTraitsRequest(combatantNames: ["Goblin 1", "Goblin 2", "Bugbear 1"])
        XCTAssertNoDifference(request.prompt(), [
            .init(role: .system, content: "You are helping a Dungeons & Dragons DM create awesome encounters."),
            .init(role: .user, content: """
                The encounter has 3 monster(s): "Goblin 1", "Goblin 2", "Bugbear 1". Come up with gritty physical and personality traits that don't interfere with its stats and unique nickname that fits its traits. One trait of each type for each monster, limit each trait to a single sentence.

                Format your answer as a correct YAML sequence of maps, with an entry for each monster. Each entry has fields name, physical, personality, nickname.
                """
            )
        ])
    }

}
