//
//  DiceRollerInvocation.swift
//  DiceRollerInvocation
//
//  Created by Thomas Visser on 20/08/2022.
//  Copyright © 2022 Thomas Visser. All rights reserved.
//

import Foundation
import Dice
import URLRouting
import Parsing
import Helpers
import Dice

public enum DiceRollerInvocation {
    case unspecified
    case qwixx
    case yahtzee
    case expression(DiceExpression)
}

public extension DiceRollerInvocation {
    var expression: DiceExpression {
        switch self {
        case .unspecified: return 1.d(20)
        case .qwixx: return .dice(count: 2, die: Die(color: nil, sides: 6))
                .appending(.dice(count: 1, die: Die(color: .red, sides: 6)))?
                .appending(.dice(count: 1, die: Die(color: .yellow, sides: 6)))?
                .appending(.dice(count: 1, die: Die(color: .green, sides: 6)))?
                .appending(.dice(count: 1, die: Die(color: .blue, sides: 6))) ?? .number(0)
        case .yahtzee: return .dice(count: 5, die: Die(color: nil, sides: 6))
        case .expression(let ex): return ex
        }
    }
}

public let diceRollerInvocationRouter = OneOf {
    Route(.case(DiceRollerInvocation.qwixx)) {
        Fragment { "qwixx"}
    }

    Route(.case(DiceRollerInvocation.yahtzee)) {
        Fragment { "yahtzee" }
    }

    Route(.case(DiceRollerInvocation.expression)) {
        Fragment { DiceExpressionParser.diceExpression() }
    }
}

public struct ParsingError: Error {
    public init() { }
}

// Bridges our parsers to Pointfree's Parsers
extension Helpers.Parser: Parsing.ParserPrinter {
    @inlinable
    public func parse(_ input: inout Substring) throws -> A {
        var remainder = Remainder(String(input))
        let res = parse(&remainder)
        input.removeFirst(remainder.position)

        guard let res = res else { throw ParsingError() }

        return res
    }

    public func print(_ output: A, into input: inout Substring) throws {
        fatalError("Printing is not supported")
    }
}
