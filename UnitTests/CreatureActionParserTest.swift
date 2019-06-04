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

class CreatureActionParserTest: XCTestCase {

    func testMeleeAttack() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage.")
        XCTAssertEqual(action, .weaponAttack(.init(type: .melee, range: .reach(5), hitModifier: Modifier(modifier: 4), effects: [.damage(.init(staticDamage: 5, damageExpression: 1.d(6)+2, type: .slashing))])))
    }

    func testMeleeAttack2() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +3 to hit, reach 5 ft., one target. Hit: 2 (1d4) bludgeoning damage")
        XCTAssertEqual(action, .weaponAttack(.init(type: .melee, range: .reach(5), hitModifier: Modifier(modifier: 3), effects: [.damage(.init(staticDamage: 2, damageExpression: 1.d(4), type: .bludgeoning))])))
    }

    func testMeleeAttackStaticDamage() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +2 to hit, reach 5 ft., one target. Hit: 1 piercing damage.")
        XCTAssertEqual(action, .weaponAttack(.init(type: .melee, range: .reach(5), hitModifier: Modifier(modifier: 2), effects: [.damage(.init(staticDamage: 1, damageExpression: nil, type: .piercing))])))
    }

    func testRangedAttack() {
        let action = CreatureActionParser.parse("Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.")
        XCTAssertEqual(action, .weaponAttack(CreatureActionParser.Action.WeaponAttack(type: .ranged, range: .range(80, 320), hitModifier: Modifier(modifier: 4), effects: [.damage(.init(staticDamage: 5, damageExpression: 1.d(6)+2, type: .piercing))])))
    }

    func testTwoDamage() {
        let action = CreatureActionParser.parse("Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 7 (1d10 + 2) piercing damage plus 3 (1d6) poison damage.")
        XCTAssertEqual(action, .weaponAttack(.init(type: .melee, range: .reach(5), hitModifier: Modifier(modifier: 4), effects: [.damage(.init(staticDamage: 7, damageExpression: 1.d(10)+2, type: .piercing)), .damage(.init(staticDamage: 3, damageExpression: 1.d(6), type: .poison))])))
    }

    func testConditionalDamage() {
        let action = CreatureActionParser.parse(
            "Melee Weapon Attack: +5 to hit, reach 5 ft., one creature. Hit: 7 (1d8 + 3) piercing damage, and the target must make a DC 11 Constitution saving throw, taking 9 (2d8) poison damage on a failed save, or half as much damage on a successful one. If the poison damage reduces the target to 0 hit points, the target is stable but poisoned for 1 hour, even after regaining hit points, and is paralyzed while poisoned in this way."
        )
        XCTAssertEqual(action, .weaponAttack(.init(type: .melee, range: .reach(5), hitModifier: Modifier(modifier: 5), effects: [.damage(.init(staticDamage: 7, damageExpression: 1.d(8)+3, type: .piercing)), .saveableDamage(.init(ability: .constitution, dc: 11, damage: .init(staticDamage: 9, damageExpression: 2.d(8), type: .poison), saveEffect: .half))])))
    }

    func testAllMonsterActions() {
        let sut = Open5eMonsterDataSourceReader(
            dataSource: FileDataSource(path: Bundle.main.path(forResource: "monsters", ofType: "json")!)
        )
        let job = sut.read()

        let e = expectation(description: "Receive at least one item")
        _ = job.items.collect().sink(receiveCompletion: { _ in
            e.fulfill()
        }, receiveValue: { items in
            var actions: [(CreatureAction, CreatureActionParser.Action?)] = []
//            self.measure {
                actions = items
                    .compactMap { $0 as? Monster }
                    .flatMap { $0.stats.actions }
                    .map {
                        ($0, CreatureActionParser.parse($0.description))
                    }
//            }


            let attacks = actions.filter { $0.0.description.lowercased().contains("weapon attack") }
            let parsed = attacks.filter {
                if case .weaponAttack(let a)? = $0.1 {
                    return a.effects.count > 0
                }
                return false
            }
            let unparsed = attacks.filter {
                if case .weaponAttack(let a)? = $0.1 {
                    return a.effects.count == 0
                }
                return true
            }
            print("total: \(attacks.count), parsed: \(parsed.count)")

            assertSnapshot(matching: actions, as: .dump)
        })

        waitForExpectations(timeout: 2, handler: nil)
    }

}
