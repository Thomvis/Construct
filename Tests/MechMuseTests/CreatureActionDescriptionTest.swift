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
        During a D&D combat encounter, a player is attacked by a monster.Attacking monster: Goblin ().The monster attacks using "Shortbow".The attack hits the player for an average 6 points of bludgeoning damage.What does the DM say to the attacked player? Describe the monster and the attack, using a gritty style.Mention the damage.
        """)
    }
}
