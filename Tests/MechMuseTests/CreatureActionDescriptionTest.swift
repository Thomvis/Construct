//
//  CreatureActionDescriptionTest.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation
import XCTest
import MechMuse
import GameModels

final class CreatureActionDescriptionTest: XCTestCase {
    func testCompendium() {
        let request = CreatureActionDescriptionRequest(
            creature: Monster(
                realm: .core,
                stats: StatBlock(name: "Goblin"),
                challengeRating: .oneEighth
            ),
            action: CreatureAction(
                id: UUID(),
                name: "Shortbow",
                description: "Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage."
            )
        )

        XCTAssertEqual(request.prompt(toneOfVoice: .gritty), """
        You are a D&D DM. Give a gritty description to a player of a monster attacking them.Attacking monster: Goblin.The monster attacks using "Shortbow": Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.The attack hits the player for 6 points of bludgeoning damage.
        """)
    }
}
