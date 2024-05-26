//
//  ParseableGameModelsVisitorTest.swift
//
//
//  Created by Thomas Visser on 13/12/2023.
//

import Foundation
import GameModels
import XCTest
import SnapshotTesting
import TestSupport

final class ParseableGameModelsVisitorTest: XCTestCase {

    func testVisitSpell() {
        let sut = ParseableGameModelsVisitor()

        var spell = Spell(
            realm: .init(CompendiumRealm.core.id),
            name: "Acid Splash",
            level: nil,
            castingTime: "1 action",
            range: "60 feet",
            components: [.verbal, .somatic],
            ritual: false,
            duration: "Instantaneous",
            school: "C",
            concentration: false,
            description: .init(input: "You hurl a bubble of acid. Choose one creature you can see within range, or choose two creatures you can see within range that are within 5 feet of each other. A target must succeed on a Dexterity saving throw or take 1d6 acid damage."),
            higherLevelDescription: "This spell's damage increases by 1d6 when you reach 5th level (2d6), 11th level (3d6), and 17th level (4d6).",
            classes: ["Sorcerer", "Wizard"],
            material: nil
        )

        let changed = sut.visit(spell: &spell)
        XCTAssertTrue(changed)

        assertSnapshot(matching: spell, as: .dump)

        // visiting again should yield no change and return false
        XCTAssertFalse(sut.visit(spell: &spell))
    }

    func testVisitStatBlock() {
        let sut = ParseableGameModelsVisitor()
        let uuidGenerator = UUID.fakeGenerator()

        var statBlock = StatBlock(
            name: "Test",
            type: "Beast",
            features: [
                CreatureFeature(
                    id: uuidGenerator(),
                    name: "Spellcasting",
                    description: "The acolyte is a 1st-level spellcaster. Its spellcasting ability is Wisdom (spell save DC 12, +4 to hit with spell attacks). The acolyte has following cleric spells prepared:\n\n• Cantrips (at will): light, sacred flame, thaumaturgy\n• 1st level (3 slots): bless, cure wounds, sanctuary"
                )
            ],
            actions: [
                CreatureAction(
                    id: uuidGenerator(),
                    name: "Scimitar",
                    description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."
                )
            ],
            reactions: [
                CreatureAction(
                    id: uuidGenerator(),
                    name: "Scimitar",
                    description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."
                )
            ],
            legendary: .init(actions: [
                .init(input: CreatureAction(
                    id: uuidGenerator(),
                    name: "",
                    description: ""
                ))
            ])
        )

        let changed = sut.visit(statBlock: &statBlock)
        XCTAssertTrue(changed)

        assertSnapshot(matching: statBlock, as: .dump)

        // visiting again should yield no change and return false
        XCTAssertFalse(sut.visit(statBlock: &statBlock))
    }
}
