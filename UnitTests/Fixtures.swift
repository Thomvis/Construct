//
//  Fixtures.swift
//  UnitTests
//
//  Created by Thomas Visser on 19/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
@testable import Construct

class Fixtures {
    static let monster = Monster(realm: .core, stats: StatBlock(name: "Monster", size: .small, type: "humanoid", subtype: "", alignment: .lawfulGood, armorClass: 10, armor: [], hitPointDice: 1.d(6), hitPoints: 3, movement: [.walk: 30], abilityScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10), savingThrows: [:], skills: [:], damageVulnerabilities: nil, damageResistances: nil, damageImmunities: nil, conditionImmunities: nil, senses: nil, languages: nil, challengeRating: Fraction(numenator: 2, denominator: 1), features: [], actions: []), challengeRating: Fraction(numenator: 2, denominator: 1))
}
