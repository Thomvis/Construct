//
//  ParseableSpellDescription.swift
//  Construct
//
//  Created by Thomas Visser on 16/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import Dice

public typealias ParseableSpellDescription = Parseable<String, ParsedSpellDescription>

public extension ParseableSpellDescription {
    var attributedDescription: AttributedString {
        guard let parsed = result?.value else { return AttributedString(input) }

        var result = AttributedString(input)
        for match in parsed.diceExpressions {
            result.apply(match) { str, expr in
                str.construct.diceExpression = expr
            }
        }
        return result
    }
}

public struct ParsedSpellDescription: Codable, Hashable {
    public let diceExpressions: [Located<DiceExpression>]
}

public struct SpellDescriptionDomainParser: DomainParser {
    public static var version: String = "1"

    public static func parse(input: String) -> ParsedSpellDescription? {
        let matches = DiceExpressionParser.diceExpression()
            .flatMap {
                // filter out expressions that are just a number
                $0.diceCount > 0 ? $0 : nil
            }
            .matches(in: input.description)

        guard !matches.isEmpty else { return nil }
        return ParsedSpellDescription(diceExpressions: matches)
    }
}
