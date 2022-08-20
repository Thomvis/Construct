//
//  DiceExpressionParser.swift
//  Construct
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import Dice

// Parses expressions like:
// - "1d6"
// - "1d6 + 1d4"
// - "+5"
enum DiceExpressionParser {

    static func parse(_ string: String) -> DiceExpression? {
        return diceExpression().run(string)
    }

    static func diceExpression() -> Parser<DiceExpression> {
        return dice().or(number()).followed(by: any(op().followed(by: dice().or(number())))).map { i in
            var res = i.0
            for (op, expr) in i.1 {
                res = .compound(res, op, expr)
            }
            return res
        }.or(modifier())
    }

    private static func dice() -> Parser<DiceExpression> {
        return int()
            .followed(by: char("d"))
            .followed(by: int())
            .map { i in
                DiceExpression.dice(count: i.0.0, die: Die(sides: i.1))
        }
    }

    static func number() -> Parser<DiceExpression> {
        return int().map {
            DiceExpression.number($0)
        }
    }

    private static func modifier() -> Parser<DiceExpression> {
        let plus = char("+").map { _ in DiceExpression.Operator.add }
        let minus = char("-").map { _ in DiceExpression.Operator.subtract }

        return plus.or(minus).followed(by: number()).map { (op, num) in
            .compound(.dice(count: 1, die: .d20), op, num)
        }
    }

    private static func op() -> Parser<DiceExpression.Operator> {
        let plus = char("+").map { _ in DiceExpression.Operator.add }
        let minus = char("-").map { _ in DiceExpression.Operator.subtract }
        let op = plus.or(minus)
        return zip(
            any(char(" ")),
            op,
            any(char(" "))
        ).map { $0.1 }
    }
}

extension DiceExpressionParser {
    /**
     Returns a match for each dice expression with at least one dice
     in the input string.
     */
    static func matches(in input: String) -> [Located<DiceExpression>] {
        DiceExpressionParser.diceExpression()
            .flatMap {
                // filter out expressions that are just a number
                $0.diceCount > 0 ? $0 : nil
            }
            .matches(in: input.description)
    }
}
