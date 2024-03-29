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
#if canImport(UIKit)
import UIKit
#endif
import Helpers

public enum RolledDiceExpression: Hashable {
    case dice(Die, [RolledDie])
    indirect case compound(RolledDiceExpression, DiceExpression.Operator, RolledDiceExpression)
    case number(Int)

    public var total: Int {
        switch self {
        case .dice(_, let dice):
            return dice.map { $0.value }.reduce(0, +)
        case .compound(let lhs, let op, let rhs):
            return op.f(lhs.total, rhs.total)
        case .number(let n):
            return n
        }
    }

    public var dice: [RolledDie] {
        switch self {
        case .dice(_, let dice):
            return dice
        case .compound(let lhs, _, let rhs):
            return lhs.dice + rhs.dice
        case .number(_):
            return []
        }
    }

    public var modifier: Int {
        switch self {
        case .dice:
            return 0
        case .compound(let lhs, let op, let rhs):
            return op.f(lhs.modifier, rhs.modifier)
        case .number(let n):
            return n
        }
    }

    public var contributingNodeCount: Int {
        switch self {
        case .dice:
            return 1
        case .compound(let lhs, _, let rhs):
            return lhs.contributingNodeCount + rhs.contributingNodeCount
        case .number(let n):
            return n != 0 ? 1 : 0
        }
    }

    public var unroll: DiceExpression {
        switch self {
        case .dice(let d, let rs): return .dice(count: rs.count, die: d)
        case .compound(let lhs, let op, let rhs): return .compound(lhs.unroll, op, rhs.unroll)
        case .number(let n): return .number(n)
        }
    }

    public mutating func rerollDice(_ index: Int) {
        var offset = index
        var rng = SystemRandomNumberGenerator()
        self = self.rerolling(&offset, rng: &rng)
    }

    public mutating func rerollDice<G>(_ index: Int, rng: inout G) where G: RandomNumberGenerator {
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

    public static func dice(die: Die, values: [Int]) -> Self {
        .dice(die, values.map { RolledDie(die: die, value: $0) })
    }
}

public struct Die: Hashable, Codable {
    public let color: Color?
    public let sides: Int

    public init(color: Color? = nil, sides: Int) {
        self.color = color
        self.sides = sides
    }

    public static var d2 = Die(sides: 2)
    public static var d4 = Die(sides: 4)
    public static var d6 = Die(sides: 6)
    public static var d8 = Die(sides: 8)
    public static var d10 = Die(sides: 10)
    public static var d12 = Die(sides: 12)
    public static var d20 = Die(sides: 20)
    public static var d100 = Die(sides: 100)

    public enum Color: String, Codable, CaseIterable {
        case red, yellow, green, blue

        #if canImport(UIKit)
        public var UIColor: UIColor {
            switch self {
            case .red: return .systemRed
            case .yellow: return .systemYellow
            case .green: return .systemGreen
            case .blue: return .systemBlue
            }
        }
        #endif
    }
}

public struct RolledDie: Hashable {
    public let id: Id = UUID().tagged()
    public let die: Die
    public var value: Int

    public typealias Id = Tagged<RolledDie, UUID>
}

public extension DiceExpression {
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
