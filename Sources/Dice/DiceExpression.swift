//
//  DiceExpression.swift
//  Construct
//
//  Created by Thomas Visser on 21/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

public enum DiceExpression: Hashable {
    case dice(count: Int, die: Die)
    indirect case compound(DiceExpression, Operator, DiceExpression)
    case number(Int)

    public mutating func append(_ expression: DiceExpression) {
        self = appending(expression) ?? .number(0)
    }

    public func appending(_ expression: DiceExpression) -> DiceExpression? {
        if let combined = combining(expression) {
            return combined
        }
        return DiceExpression.compound(self, .add, expression).normalized
    }

    // Returns and expression if the given expression can be combined with self
    // without increasing the number of nodes
    private func combining(_ expression: DiceExpression) -> DiceExpression? {
        switch (self, expression) {
        case (.dice(let count, let die), .dice(let eCount, let eDie)) where die == eDie:
            return .dice(count: count + eCount, die: die)
        case (.compound(let lhs, let op, let rhs), _):
            guard let newRhs = rhs.combining(op.isSubtract ? expression.opposite : expression) else {
                return nil
            }
            return DiceExpression.compound(lhs, op, newRhs).normalized
        case (.number(let lhs), .number(let rhs)):
            return .number(lhs + rhs)
        case (.number(0), _):
            return expression
        default:
            return nil
        }
    }

    public var minimum: Int {
        switch self {
        case .dice(let count, _):
            return count
        case .compound(let lhs, let op, let rhs):
            switch op {
            case .add: return lhs.minimum + rhs.minimum
            case .subtract: return lhs.minimum - rhs.maximum
            }
        case .number(let n):
            return n
        }
    }

    public var maximum: Int {
        switch self {
        case .dice(let count, let die):
            return count * die.sides
        case .compound(let lhs, let op, let rhs):
            switch op {
            case .add: return lhs.maximum + rhs.maximum
            case .subtract: return lhs.maximum - rhs.minimum
            }
        case .number(let n):
            return n
        }
    }

    public var diceCount: Int {
        switch self {
        case .dice(let count, _):
            return count
        case .compound(let lhs, _, let rhs):
            return lhs.diceCount + rhs.diceCount
        case .number:
            return 0
        }
    }

    // Ensures that the following is true:
    // - dice counts are non-negative
    // - zero-count dice are removed
    // - the number 0 is removed
    public var normalized: DiceExpression? {
        switch self {
        case .compound(let lhs, let op, let rhs) where rhs.ordinal.map { $0 < 0 } ?? false:
            return .compound(lhs, op.opposite, rhs.opposite)
        case .compound(let lhs, let op, let rhs):
            switch (lhs.normalized, rhs.normalized) {
            case (let lhs?, let rhs?): return .compound(lhs, op, rhs)
            case (nil, let rhs?): return op.isSubtract ? rhs.opposite : rhs
            case (let lhs?, nil): return lhs
            case (nil, nil): return nil
            }
        case .dice(count: 0, die: _): return nil
        case .number(0): return nil
        default:
            return self
        }
    }

    public var opposite: DiceExpression {
        switch self {
        case .dice(let count, let die):
            return .dice(count: count * -1, die: die)
        case .compound(let lhs, let op, let rhs):
            return .compound(lhs.opposite, op, rhs.opposite)
        case .number(let n):
            return .number(n * -1)
        }
    }

    public var ordinal: Int? {
        switch self {
        case .dice(let count, _):
            return count
        case .compound:
            return nil
        case .number(let n):
            return n
        }
    }

    public func color(_ color: Die.Color?) -> DiceExpression {
        switch self {
        case .dice(let count, let die):
            return .dice(count: count, die: Die(color: color, sides: die.sides))
        case .compound(let lhs, let op, let rhs):
            return .compound(lhs.color(color), op, rhs.color(color))
        case .number(let n):
            return .number(n)
        }
    }

    public enum Operator: Int, Codable {
        case add, subtract

        var isSubtract: Bool {
            switch self {
            case .add: return false
            case .subtract: return true
            }
        }

        func f(_ lhs: Int, _ rhs: Int) -> Int {
            switch self {
            case .add: return lhs + rhs
            case .subtract: return lhs - rhs
            }
        }

        public var opposite: Operator {
            switch self {
            case .add: return .subtract
            case .subtract: return .add
            }
        }

        public var string: String {
            switch self {
            case .add: return "+"
            case .subtract: return "-"
            }
        }
    }
}

public protocol DiceExpressionConvertible {
    var diceExpression: DiceExpression { get }
}

extension DiceExpression: DiceExpressionConvertible {
    public var diceExpression: DiceExpression { self }
}

extension Int: DiceExpressionConvertible {
    public func d(_ sides: Int) -> DiceExpression {
        .dice(count: self, die: Die(sides: sides))
    }

    public var diceExpression: DiceExpression {
        .number(self)
    }
}

public func +(lhs: DiceExpressionConvertible, rhs: DiceExpressionConvertible) -> DiceExpression {
    .compound(lhs.diceExpression, .add, rhs.diceExpression)
}

public func -(lhs: DiceExpressionConvertible, rhs: DiceExpressionConvertible) -> DiceExpression {
    .compound(lhs.diceExpression, .subtract, rhs.diceExpression)
}

extension DiceExpression: Codable {
    enum CodingErrors: Error {
        case unrecognizedExpression
    }
    enum CodingKeys: CodingKey {
        case diceCount, diceDie, compoundLhs, compoundOperator, compoundRhs, number
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let diceCount = try? container.decode(Int.self, forKey: .diceCount),
            let diceDie = try? container.decode(Die.self, forKey: .diceDie) {
            self = .dice(count: diceCount, die: diceDie)
        } else if let lhs = try? container.decode(DiceExpression.self, forKey: .compoundLhs),
            let op = try? container.decode(Operator.self, forKey: .compoundOperator),
            let rhs = try? container.decode(DiceExpression.self, forKey: .compoundRhs) {
            self = .compound(lhs, op, rhs)
        } else if let n = try? container.decode(Int.self, forKey: .number) {
            self = .number(n)
        } else {
            throw CodingErrors.unrecognizedExpression
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .dice(let count, let die):
            try container.encode(count, forKey: .diceCount)
            try container.encode(die, forKey: .diceDie)
        case .compound(let lhs, let op, let rhs):
            try container.encode(lhs, forKey: .compoundLhs)
            try container.encode(op, forKey: .compoundOperator)
            try container.encode(rhs, forKey: .compoundRhs)
        case .number(let n):
            try container.encode(n, forKey: .number)
        }
    }
}

extension DiceExpression: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dice(let count, let die): return "\(count)d\(die.sides)"
        case .compound(let lhs, let op, let rhs): return "\(lhs.description) \(op.string) \(rhs.description)"
        case .number(let n): return "\(n)"
        }
    }
}
