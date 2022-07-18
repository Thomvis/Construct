//
//  RolledDiceExpression.swift
//  Construct
//
//  Created by Thomas Visser on 30/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Tagged
//import UIKit

enum RolledDiceExpression: Hashable {
    case dice(Die, [RolledDie])
    indirect case compound(RolledDiceExpression, DiceExpression.Operator, RolledDiceExpression)
    case number(Int)

    var total: Int {
        switch self {
        case .dice(_, let dice):
            return dice.map { $0.value }.reduce(0, +)
        case .compound(let lhs, let op, let rhs):
            return op.f(lhs.total, rhs.total)
        case .number(let n):
            return n
        }
    }

    var dice: [RolledDie] {
        switch self {
        case .dice(_, let dice):
            return dice
        case .compound(let lhs, _, let rhs):
            return lhs.dice + rhs.dice
        case .number(_):
            return []
        }
    }

    var modifier: Int {
        switch self {
        case .dice:
            return 0
        case .compound(let lhs, let op, let rhs):
            return op.f(lhs.modifier, rhs.modifier)
        case .number(let n):
            return n
        }
    }

    var contributingNodeCount: Int {
        switch self {
        case .dice:
            return 1
        case .compound(let lhs, _, let rhs):
            return lhs.contributingNodeCount + rhs.contributingNodeCount
        case .number(let n):
            return n != 0 ? 1 : 0
        }
    }

    var unroll: DiceExpression {
        switch self {
        case .dice(let d, let rs): return .dice(count: rs.count, die: d)
        case .compound(let lhs, let op, let rhs): return .compound(lhs.unroll, op, rhs.unroll)
        case .number(let n): return .number(n)
        }
    }

    mutating func rerollDice(_ index: Int) {
        var offset = index
        var rng = SystemRandomNumberGenerator()
        self = self.rerolling(&offset, rng: &rng)
    }

    mutating func rerollDice<G>(_ index: Int, rng: inout G) where G: RandomNumberGenerator {
        var offset = index
        self = self.rerolling(&offset, rng: &rng)
    }

    private func rerolling<G>(_ offset: inout Int, rng: inout G) -> RolledDiceExpression where G: RandomNumberGenerator {
        guard offset >= 0 else { return self }
        switch self {
        case .dice(let die, let dice):
            var newDice = dice
            if offset < dice.count {
                newDice[offset] = RolledDie(die: die, value: rng.randomInt(in: 1...die.sides))
            }
            offset -= dice.count
            return .dice(die, newDice)
        case .compound(let lhs, let op, let rhs):
            return .compound(lhs.rerolling(&offset, rng: &rng), op, rhs.rerolling(&offset, rng: &rng))
        case .number:
            return self
        }
    }

    static func dice(die: Die, values: [Int]) -> Self {
        .dice(die, values.map { RolledDie(die: die, value: $0) })
    }
}

struct Die: Hashable, Codable {
    let color: Color?
    let sides: Int

    init(color: Color? = nil, sides: Int) {
        self.color = color
        self.sides = sides
    }

    static var d2 = Die(sides: 2)
    static var d4 = Die(sides: 4)
    static var d6 = Die(sides: 6)
    static var d8 = Die(sides: 8)
    static var d10 = Die(sides: 10)
    static var d12 = Die(sides: 12)
    static var d20 = Die(sides: 20)
    static var d100 = Die(sides: 100)

    enum Color: String, Codable, CaseIterable {
        case red, yellow, green, blue

        var swiftUIColor: SwiftUI.Color {
            switch self {
            case .red: return .systemRed
            case .yellow: return .systemYellow
            case .green: return .systemGreen
            case .blue: return .systemBlue
            }
        }
    }
}

struct RolledDie: Hashable {
    let id: Id = UUID().tagged()
    let die: Die
    var value: Int

    typealias Id = Tagged<RolledDie, UUID>
}

extension DiceExpression {
    var roll: RolledDiceExpression {
        guard let normalized = self.normalized else {
            return .number(0)
        }

        var rng = SystemRandomNumberGenerator()
        return normalized.roll(rng: &rng)
    }

    func roll<G>(rng: inout G) -> RolledDiceExpression where G: RandomNumberGenerator {
        switch self {
        case .dice(let count, let die):
            if count < 0 {
                return .compound(.number(0), .subtract, DiceExpression.dice(count: abs(count), die: die).roll(rng: &rng))
            }
            return .dice(die, (0..<abs(count)).map { _ in RolledDie(die: die, value: rng.randomInt(in: 1...die.sides)) })
        case .compound(let lhs, let op, let rhs):
            return .compound(lhs.roll(rng: &rng), op, rhs.roll(rng: &rng))
        case .number(let n):
            return .number(n)
        }
    }
}
