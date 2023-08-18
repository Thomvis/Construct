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
import CustomDump

final class CreatureActionDescriptionTest: XCTestCase {
    func testPrompt() {
        let request = CreatureActionDescriptionRequest(
            creature: Monster(
                realm: .init(CompendiumRealm.core.id),
                stats: StatBlock(name: "Goblin"),
                challengeRating: .oneEighth
            ),
            action: CreatureAction(
                id: UUID(),
                name: "Shortbow",
                description: "Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage."
            )
        )

        XCTAssertNoDifference(request.prompt(), [
            .init(role: .system, content: "You are a Dungeons & Dragons DM."),
            .init(role: .user, content: """
                During a combat encounter, a player is attacked by a monster.Attacking monster: Goblin ().The monster attacks using "Shortbow".The attack is a hit, dealing 6 points of bludgeoning damage.Narrate the attack, focus on the monster and the attack, using a gritty style.Mention the damage.
                """
            )
        ])
    }
}
