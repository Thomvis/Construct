//
//  ProficiencyBonus.swift
//  
//
//  Created by Thomas Visser on 20/11/2022.
//

import Foundation
import Helpers

// Helps with the definition of the mapping below
private func / (lhs: Int, rhs: Int) -> Fraction {
    Fraction(numenator: lhs, denominator: rhs)
}

public let crToProficiencyBonusMapping: [Fraction: Modifier] = [
    Fraction(integer: 0): 2,
    1 / 8: 2,
    1 / 4: 2,
    1 / 2: 2,
    1: 2,
    2: 2,
    3: 2,
    4: 2,
    5: 3,
    6: 3,
    7: 3,
    8: 3,
    9: 4,
    10: 4,
    11: 4,
    12: 4,
    13: 5,
    14: 5,
    15: 5,
    16: 5,
    17: 6,
    18: 6,
    19: 6,
    20: 6,
    21: 7,
    22: 7,
    23: 7,
    24: 7,
    25: 8,
    26: 8,
    27: 8,
    28: 8,
    29: 9,
    30: 9
]

public let levelToProficiencyBonusMapping: [Int: Modifier] = [
    1: 2,
    2: 2,
    3: 2,
    4: 2,
    5: 3,
    6: 3,
    7: 3,
    8: 3,
    9: 4,
    10: 4,
    11: 4,
    12: 4,
    13: 5,
    14: 5,
    15: 5,
    16: 5,
    17: 6,
    18: 6,
    19: 6,
    20: 6
]
