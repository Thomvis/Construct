//
//  DiceExpressionParser.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 23/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

// Parses expressions like:
// - "1d6"
// - "1d6 + 1d4"
class DiceExpressionParser {

    static func parse(_ string: String) -> DiceExpression? {
        return diceExpression().run(string)
    }

    static func diceExpression() -> Parser<DiceExpression> {
        let plus = char("+").map { _ in DiceExpression.Operator.add }
        let minus = char("-").map { _ in DiceExpression.Operator.subtract }
        let op = plus.or(minus)
        let paddedOp = zip(
            any(char(" ")),
            op,
            any(char(" "))
        ).map { $0.1 }


        return dice().or(number()).followed(by: any(paddedOp.followed(by: dice().or(number())))).map { i in
            var res = i.0
            for (op, expr) in i.1 {
                res = .compound(res, op, expr)
            }
            return res
        }
    }
}
