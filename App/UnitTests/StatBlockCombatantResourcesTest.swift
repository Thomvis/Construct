//
//  StatBlockCombatantResourcesTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 20/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import Combine
import GameModels
import Helpers

class StatBlockCombatantResourcesTest: XCTestCase {

    func testSpellcasting() {
        var monster = Fixtures.monster
        monster.stats.features = [CreatureFeature(name: "Spellcasting", description: "The naga is an 11th-level spellcaster. Its spellcasting ability is Wisdom (spell save DC 16, +8 to hit with spell attacks), and it needs only verbal components to cast its spells. It has the following cleric spells prepared:\n\n• Cantrips (at will): mending, sacred flame, thaumaturgy\n• 1st level (4 slots): command, cure wounds, shield of faith\n• 2nd level (3 slots): calm emotions, hold person\n• 3rd level (3 slots): bestow curse, clairvoyance\n• 4th level (3 slots): banishment, freedom of movement\n• 5th level (2 slots): flame strike, geas\n• 6th level (1 slot): true seeing")]
            .map { apply(ParseableCreatureFeature(input: $0)) { $0.parseIfNeeded() } }
        monster.stats.actions = []

        let resources = monster.stats.extractResources()
        XCTAssertEqual(resources.count, 6)
        XCTAssertEqual(resources[0].title, "1st level spell slots")
        XCTAssertEqual(resources[0].slots, [false, false, false, false])
        XCTAssertEqual(resources[5].title, "6th level spell slots")
        XCTAssertEqual(resources[5].slots, [false])
    }

    func testInnateSpellcasting() {
        var monster = Fixtures.monster
        monster.stats.features = [CreatureFeature(name: "Innate Spellcasting", description: "The giant's innate spellcasting ability is Charisma. It can innately cast the following spells, requiring no material components:\n\nAt will: detect magic, fog cloud, light\n3/day each: feather fall, fly, misty step, telekinesis\n1/day each: control weather, gaseous form")]
            .map { apply(ParseableCreatureFeature(input: $0)) { $0.parseIfNeeded() } }
        monster.stats.actions = []

        let resources = monster.stats.extractResources()
        XCTAssertEqual(resources.count, 6)
        XCTAssertEqual(resources[0].title, "feather fall (3/Day)")
        XCTAssertEqual(resources[0].slots, [false, false, false])
        XCTAssertEqual(resources[5].title, "gaseous form (1/Day)")
        XCTAssertEqual(resources[5].slots, [false])
    }

    func testRechargingFeature() {
        var monster = Fixtures.monster
        monster.stats.features = [CreatureFeature(name: "Relentless (Recharges after a Short or Long Rest)", description: "If the boar takes 7 damage or less that would reduce it to 0 hit points, it is reduced to 1 hit point instead.")]
            .map { apply(ParseableCreatureFeature(input: $0)) { $0.parseIfNeeded() } }
        monster.stats.actions = []

        let resources = monster.stats.extractResources()
        XCTAssertEqual(resources.count, 1)
        XCTAssertEqual(resources[0].title, "Relentless (Recharges after a Short or Long Rest)")
        XCTAssertEqual(resources[0].slots, [false])
    }

    func testRechargingAction() {
        var monster = Fixtures.monster
        monster.stats.features = []
        monster.stats.actions = [CreatureAction(name: "Cold Breath (Recharge 5-6)", description: "The dragon exhales an icy blast of hail in a 15-foot cone. Each creature in that area must make a DC 12 Constitution saving throw, taking 22 (5d8) cold damage on a failed save, or half as much damage on a successful one.")]
            .map { apply(ParseableCreatureAction(input: $0)) { $0.parseIfNeeded() } }

        let resources = monster.stats.extractResources()
        XCTAssertEqual(resources.count, 1)
        XCTAssertEqual(resources[0].title, "Cold Breath (Recharge 5-6)")
        XCTAssertEqual(resources[0].slots, [false])
    }

    func testLegendaryActions() {
        var monster = Fixtures.monster
        monster.stats.legendary = .init(description: "Acererak can take 5 legendary actions, choosing", actions: [])

        let resources = monster.stats.extractResources()
        XCTAssertEqual(resources.count, 1)
        XCTAssertEqual(resources[0].title, "Legendary Actions")
        XCTAssertEqual(resources[0].slots, [false, false, false, false, false])
    }
}
