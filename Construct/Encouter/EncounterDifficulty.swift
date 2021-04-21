//
//  EncounterDifficulty.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct EncounterDifficulty {
    let party: [PartyEntry] // PC levels
    let monsters: [Fraction] // Challenge ratings

    let partyThresholds: EncounterDifficultyThresholds
    let adjustedXp: Int // A value used to measure an encounter difficulty (not to reward the players)

    init(party: [Int], monsters: [Fraction]) {
        self.init(party: party.map { .init(level: $0, name: nil) }, monsters: monsters)
    }

    init(party: [PartyEntry], monsters: [Fraction]) {
        precondition(!party.isEmpty)
        self.party = party
        self.monsters = monsters

        self.partyThresholds = party.compactMap { difficultyThresholdsByCharacterLevel[$0.level] }.reduce(.zero, +)
        self.adjustedXp = Self.adjustedEncounterXp(party: party.map { $0.level }, monsters: monsters)
    }

    var category: Category? {
        for c in Category.allCases.reversed() {
            if partyThresholds.value(for: c) <= adjustedXp {
                return c
            }
        }
        return nil
    }

    var percentageOfDeadly: CGFloat {
        CGFloat(adjustedXp) / CGFloat(partyThresholds.deadly)
    }

    func percentageOfDeadly(_ category: Category) -> CGFloat {
        CGFloat(partyThresholds.value(for: category)) / CGFloat(partyThresholds.deadly)
    }

    enum Category: String, CaseIterable, Equatable, Identifiable {
        case easy
        case medium
        case hard
        case deadly

        var id: RawValue { rawValue }
    }

    struct PartyEntry {
        let level: Int
        let name: String?
    }
}

extension EncounterDifficulty {
    private static func adjustedEncounterXp(party: [Int], monsters: [Fraction]) -> Int {
        let monsterTotalXp = monsters.compactMap { crToXpMapping[$0] }.reduce(0, +)

        // todo: exclude super weak monsters in count
        let monsterCount = monsters.count

        // multiply
        var multiplierIndex = monsterCountMultiplier.firstIndex { $0.0.contains(monsterCount) } ?? 0

        if party.count < 3 {
            multiplierIndex = min(multiplierIndex+1, monsterCountMultiplier.count-1)
        } else if party.count > 5 {
            multiplierIndex = max(multiplierIndex-1, 0)
        }

        return Int(round(Float(monsterTotalXp) * monsterCountMultiplier[multiplierIndex].1))
    }
}



struct EncounterDifficultyThresholds {
    let easy: Int
    let medium: Int
    let hard: Int
    let deadly: Int

    func value(for category: EncounterDifficulty.Category) -> Int {
        switch category {
        case .easy: return easy
        case .medium: return medium
        case .hard: return hard
        case .deadly: return deadly
        }
    }

    static func +(lhs: EncounterDifficultyThresholds, rhs: EncounterDifficultyThresholds) -> EncounterDifficultyThresholds {
        return EncounterDifficultyThresholds(easy: lhs.easy + rhs.easy, medium: lhs.medium + rhs.medium, hard: lhs.hard + rhs.hard, deadly: lhs.deadly + rhs.deadly)
    }

    static var zero = EncounterDifficultyThresholds(easy: 0, medium: 0, hard: 0, deadly: 0)
}

let crToXpMapping: [Fraction: Int] = [
    Fraction(integer: 0): 10,
    Fraction(numenator: 1, denominator: 8): 25,
    Fraction(numenator: 1, denominator: 4): 50,
    Fraction(numenator: 1, denominator: 2): 100,
    Fraction(integer: 1): 200,
    Fraction(integer: 2): 450,
    Fraction(integer: 3): 700,
    Fraction(integer: 4): 1100,
    Fraction(integer: 5): 1800,
    Fraction(integer: 6): 2300,
    Fraction(integer: 7): 2900,
    Fraction(integer: 8): 3900,
    Fraction(integer: 9): 5000,
    Fraction(integer: 10): 5900,
    Fraction(integer: 11): 7200,
    Fraction(integer: 12): 8400,
    Fraction(integer: 13): 10000,
    Fraction(integer: 14): 11500,
    Fraction(integer: 15): 13000,
    Fraction(integer: 16): 15000,
    Fraction(integer: 17): 18000,
    Fraction(integer: 18): 20000,
    Fraction(integer: 19): 22000,
    Fraction(integer: 20): 25000,
    Fraction(integer: 21): 33000,
    Fraction(integer: 22): 41000,
    Fraction(integer: 23): 50000,
    Fraction(integer: 24): 62000,
    Fraction(integer: 25): 75000,
    Fraction(integer: 26): 90000,
    Fraction(integer: 27): 105000,
    Fraction(integer: 28): 120000,
    Fraction(integer: 29): 135000,
    Fraction(integer: 30): 155000
]

let monsterCountMultiplier: [(ClosedRange<Int>, Float)] = [
    (0...0, 0.5),
    (0...1, 1),
    (2...2, 1.5),
    (3...6, 2),
    (7...10, 2.5),
    (11...14, 3),
    (15...Int.max, 4)
]

let difficultyThresholdsByCharacterLevel: [Int: EncounterDifficultyThresholds] = [
    1: EncounterDifficultyThresholds(easy: 25, medium: 50, hard: 75, deadly: 100),
    2: EncounterDifficultyThresholds(easy: 50, medium: 100, hard: 150, deadly: 200),
    3: EncounterDifficultyThresholds(easy: 75, medium: 150, hard: 225, deadly: 400),
    4: EncounterDifficultyThresholds(easy: 125, medium: 250, hard: 375, deadly: 500),
    5: EncounterDifficultyThresholds(easy: 250, medium: 500, hard: 750, deadly: 1100),
    6: EncounterDifficultyThresholds(easy: 300, medium: 600, hard: 900, deadly: 1400),
    7: EncounterDifficultyThresholds(easy: 350, medium: 750, hard: 1100, deadly: 1700),
    8: EncounterDifficultyThresholds(easy: 450, medium: 900, hard: 1400, deadly: 2100),
    9: EncounterDifficultyThresholds(easy: 550, medium: 1100, hard: 1600, deadly: 2400),
    10: EncounterDifficultyThresholds(easy: 600, medium: 1200, hard: 1900, deadly: 2800),
    11: EncounterDifficultyThresholds(easy: 800, medium: 1600, hard: 2400, deadly: 3600),
    12: EncounterDifficultyThresholds(easy: 1000, medium: 2000, hard: 3000, deadly: 4500),
    13: EncounterDifficultyThresholds(easy: 1100, medium: 2200, hard: 3400, deadly: 5100),
    14: EncounterDifficultyThresholds(easy: 1250, medium: 2500, hard: 3800, deadly: 5700),
    15: EncounterDifficultyThresholds(easy: 1400, medium: 2800, hard: 4300, deadly: 6400),
    16: EncounterDifficultyThresholds(easy: 1600, medium: 3200, hard: 4800, deadly: 7200),
    17: EncounterDifficultyThresholds(easy: 2000, medium: 3900, hard: 5900, deadly: 8800),
    18: EncounterDifficultyThresholds(easy: 2100, medium: 4200, hard: 6300, deadly: 9500),
    19: EncounterDifficultyThresholds(easy: 2400, medium: 4900, hard: 7300, deadly: 10900),
    20: EncounterDifficultyThresholds(easy: 2800, medium: 5700, hard: 8500, deadly: 12700)
]
