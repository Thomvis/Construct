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
        XCTAssertNoDifference(request.messages(), [
            .init(role: .system, content: "You are helping a Dungeons & Dragons DM create awesome encounters."),
            .init(role: .user, content: "Describe gritty physical and personality traits and a unique nickname for each of the following combatants: Goblin 1, Goblin 2, Bugbear 1. Respond in JSON with an object that has a `combatants` array of objects each containing `name`, `physical`, `personality`, and `nickname`.")
        ])
    }
}
