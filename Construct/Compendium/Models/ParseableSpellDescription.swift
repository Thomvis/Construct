//
//  ParseableSpellDescription.swift
//  Construct
//
//  Created by Thomas Visser on 16/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

typealias ParseableSpellDescription = Parseable<String, ParsedSpellDescription, SpellDescriptionDomainParser>

extension ParseableSpellDescription {
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

struct ParsedSpellDescription: Codable, Hashable {
    let diceExpressions: [Located<DiceExpression>]
}

struct SpellDescriptionDomainParser: DomainParser {
    static var version: String = "1"

    static func parse(input: String) -> ParsedSpellDescription? {
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
