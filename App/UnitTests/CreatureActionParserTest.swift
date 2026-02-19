//
//  CreatureActionParserTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 31/08/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import SnapshotTesting
import CustomDump
import GameModels
import Dice
import Compendium
import ComposableArchitecture

class CreatureActionParserTest: XCTestCase {

    func testMeleeAttack() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage.")
        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 4,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(staticDamage: 5, damageExpression: 1.d(6)+2, type: .slashing)
                ])
            ]
        )))
    }

    func testMeleeAttack2() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +3 to hit, reach 5 ft., one target. Hit: 2 (1d4) bludgeoning damage")
        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 3,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 2,
                        damageExpression: 1.d(4),
                        type: .bludgeoning
                    )
                ])
            ]
        )))
    }

    func testMeleeAttackWithoutHitKeyword() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +3 to hit, reach 5 ft., one target. 2 (1d4) bludgeoning damage")
        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 3,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 2,
                        damageExpression: 1.d(4),
                        type: .bludgeoning
                    )
                ])
            ]
        )))
    }

    func testMeleeAttackStaticDamage() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +2 to hit, reach 5 ft., one target. Hit: 1 piercing damage.")

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 2,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 1,
                        damageExpression: nil,
                        type: .piercing
                    )
                ])
            ]
        )))
    }

    func testRangedAttack() {
        let action = CreatureActionParser.parse("Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.")

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 4,
            ranges: [.range(80, 320)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 5,
                        damageExpression: 1.d(6)+2,
                        type: .piercing
                    )
                ])
            ]
        )))
    }

    func testTwoDamage() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 7 (1d10 + 2) piercing damage plus 3 (1d6) poison damage.")

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 4,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 7,
                        damageExpression: 1.d(10)+2,
                        type: .piercing
                    ),
                    .init(
                        staticDamage: 3,
                        damageExpression: 1.d(6),
                        type: .poison
                    )
                ])
            ]
        )))
    }

    func testCreatureCondition() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one creature. Hit: 6 (1d8 + 2) bludgeoning damage, and the target is grappled (escape DC 14). Until this grapple ends, the creature is restrained, and the snake can't constrict another target.")

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 4,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 6,
                        damageExpression: 1.d(8)+2,
                        type: .bludgeoning
                    )
                ]),
                .init(
                    condition: .init(condition: .grappled, comment: "escape dc 14")
                )
            ]
        )))
    }

    func testConditionalDamage() {
        let action = CreatureActionParser.parse(
            "Melee Weapon Attack: +5 to hit, reach 5 ft., one creature. Hit: 7 (1d8 + 3) piercing damage, and the target must make a DC 11 Constitution saving throw, taking 9 (2d8) poison damage on a failed save, or half as much damage on a successful one. If the poison damage reduces the target to 0 hit points, the target is stable but poisoned for 1 hour, even after regaining hit points, and is paralyzed while poisoned in this way."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 5,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 7,
                        damageExpression: 1.d(8)+3,
                        type: .piercing
                    )
                ]),
                .init(
                    conditions: .init(savingThrow: .init(
                        ability: .constitution,
                        dc: 11,
                        saveEffect: .half
                    )),
                    damage: [.init(
                        staticDamage: 9,
                        damageExpression: 2.d(8),
                        type: .poison
                    )]
                )
            ]
        )))
    }

    func testOtherConditionalEffect() {
        let action = CreatureActionParser.parse(
            "Melee Weapon Attack: +9 to hit, reach 10 ft., one target. Hit: 12 (2d6 + 5) bludgeoning damage. If the target is a creature, it must succeed on a DC 14 Constitution saving throw or become diseased. The disease has no effect for 1 minute and can be removed by any magic that cures disease. After 1 minute, the diseased creature's skin becomes translucent and slimy, the creature can't regain hit points unless it is underwater, and the disease can be removed only by heal or another disease-curing spell of 6th level or higher. When the creature is outside a body of water, it takes 6 (1d12) acid damage every 10 minutes unless moisture is applied to the skin before 10 minutes have passed."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 9,
            ranges: [.reach(10)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 12,
                        damageExpression: 2.d(6)+5,
                        type: .bludgeoning
                    )
                ]),
                .init(
                    conditions: .init(
                        savingThrow: .init(
                            ability: .constitution,
                            dc: 14,
                            saveEffect: .none
                        ),
                        other: "the target is a creature"
                    ),
                    other: "become diseased"
                )
            ]
        )))
    }

    func testOtherSavondThrowConditionedEffect() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +14 to hit, reach 30 ft., one target. Hit: 15 (2d6 + 8) slashing damage plus 10 (3d6) fire damage, and the target must succeed on a DC 20 Strength saving throw or be pulled up to 25 feet toward the balor."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 14,
            ranges: [.reach(30)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 15,
                        damageExpression: 2.d(6)+8,
                        type: .slashing
                    ),
                    .init(
                        staticDamage: 10,
                        damageExpression: 3.d(6),
                        type: .fire
                    )
                ]),
                .init(
                    conditions: .init(
                        savingThrow: .init(
                            ability: .strength,
                            dc: 20,
                            saveEffect: .none
                        )
                    ),
                    other: "be pulled up to 25 feet toward the balor"
                )
            ]
        )))
    }

    func testIfThenEffectParser() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 10 (2d6 + 3) slashing damage plus 3 (1d6) acid damage. If the target is a Large or smaller creature, it is grappled (escape DC 13). Until this grapple ends, the ankheg can bite only the grappled creature and has advantage on attack rolls to do so."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 5,
            ranges: [.reach(5)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 10,
                        damageExpression: 2.d(6)+3,
                        type: .slashing
                    ),
                    .init(
                        staticDamage: 3,
                        damageExpression: 1.d(6),
                        type: .acid
                    )
                ]),
                .init(
                    conditions: .init(
                        other: "the target is a large or smaller creature"
                    ),
                    condition: .init(condition: .grappled, comment: "escape dc 13")
                )
            ]
        )))
    }

    func testTwoAttackTypes() {
        let action = CreatureActionParser.parse(
            "Melee or Ranged Weapon Attack: +6 to hit, reach 5 ft. or range 20/60 ft., one target. Hit: 4 (1d4 + 2) piercing damage."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 6,
            ranges: [.reach(5), .range(20, 60)],
            effects: [
                .init(damage: [
                    .init(
                        staticDamage: 4,
                        damageExpression: 1.d(4)+2,
                        type: .piercing
                    )
                ])
            ]
        )))
    }

    func testTwoAttachTypesWithDifferentDamage() {
        let action = CreatureActionParser.parse(
        "Melee or Ranged Weapon Attack: +4 to hit, reach 5 ft. or range 30/120 ft., one target. Hit: 9 (2d6 + 2) piercing damage in melee or 5 (1d6 + 2) piercing damage at range."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 4,
            ranges: [.reach(5), .range(30, 120)],
            effects: [
                .init(conditions: .init(type: .melee), damage: [
                    .init(
                        staticDamage: 9,
                        damageExpression: 2.d(6)+2,
                        type: .piercing
                    )
                ]),
                .init(conditions: .init(type: .ranged), damage: [
                    .init(
                        staticDamage: 5,
                        damageExpression: 1.d(6)+2,
                        type: .piercing
                    )
                ])
            ]
        )))
    }

    func testOneOrTwoHands() {
        let action = CreatureActionParser.parse(
            "Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 7 (1d8 + 3) bludgeoning damage, or 8 (1d10 + 3) bludgeoning damage if used with two hands to make a melee attack, plus 3 (1d6) fire damage."
        )

        expectNoDifference(action, .weaponAttack(.init(
            hitModifier: 5,
            ranges: [.reach(5)],
            effects: [
                .init(conditions: .init(versatileWeaponGrip: .oneHanded), damage: [
                    .init(
                        staticDamage: 7,
                        damageExpression: 1.d(8)+3,
                        type: .bludgeoning
                    )
                ]),
                .init(conditions: .init(versatileWeaponGrip: .twoHanded), damage: [
                    .init(
                        staticDamage: 8,
                        damageExpression: 1.d(10)+3,
                        type: .bludgeoning
                    )
                ]),
                .init(damage: [
                    .init(
                        staticDamage: 3,
                        damageExpression: 1.d(6),
                        type: .fire
                    )
                ])
            ]
        )))
    }

    @MainActor
    func testAllMonsterActions() async throws {
        let sut = Open5eDataSourceReader(
            dataSource: FileDataSource(path: defaultMonstersPath).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
            generateUUID: UUIDGenerator.fake().callAsFunction
        )

        let items = try await Array(sut.items(realmId: CompendiumRealm.core.id).compactMap { $0.item })

        struct ParseResult {
            let creatureName: String
            let actionName: String
            let actionDescription: String
            let parsedAction: CreatureActionParser.Action?
            let remainder: String?
        }

        let actions: [ParseResult] = items
            .compactMap { $0 as? Monster }
            .flatMap { (creature: Monster) in
                creature.stats.actions
                    .filter { action in
                        action.description.contains(Regex<Substring>(verbatim: "weapon attack").ignoresCase())
                    }
                    .map { action in
                        let res = CreatureActionParser.parseRaw(action.description)
                        return ParseResult(
                            creatureName: creature.title,
                            actionName: action.name,
                            actionDescription: action.description,
                            parsedAction: res?.1,
                            remainder: res?.0.string()
                        )
                    }
//                    .filter { $0.remainder != "." && $0.remainder != "" }
            }

        assertSnapshot(of: actions, as: .dump, record: false)
    }

    @MainActor
    func testParsePerformance() async throws {
        let sut = Open5eDataSourceReader(
            dataSource: FileDataSource(path: defaultMonstersPath).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
            generateUUID: UUIDGenerator.fake().callAsFunction
        )

        let items = try await Array(sut.items(realmId: CompendiumRealm.core.id).compactMap { $0.item })

        measure {
            for item in items {
                guard let monster = item as? Monster else { continue }
                for action in monster.stats.actions {
                    guard action.description.contains(Regex<Substring>(verbatim: "weapon attack").ignoresCase()) else { continue }
                    _ = CreatureActionParser.parseRaw(action.description)
                }
            }
        }

    }

}
