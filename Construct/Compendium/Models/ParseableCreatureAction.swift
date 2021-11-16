//
//  ParseableCreatureAction.swift
//  Construct
//
//  Created by Thomas Visser on 16/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

typealias ParseableCreatureAction = Parseable<CreatureAction, ParsedCreatureAction, CreatureActionDomainParser>

extension ParseableCreatureAction {
    var name: String { input.name }
    var description: String { input.description }
    var attributedDescription: AttributedString {
        guard let parsed = result?.value else { return AttributedString(description) }

        var result = AttributedString(description)
        for match in parsed.diceExpressions {
            result.apply(match) { str, expr in
                str.construct.diceExpression = expr
            }
        }
        return result
    }
}


struct CreatureActionDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureAction) -> ParsedCreatureAction? {
        let action = CreatureActionParser.parse(input.description)
        let matches = DiceExpressionParser.diceExpression()
            .flatMap {
                // filter out expressions that are just a number
                $0.diceCount > 0 ? $0 : nil
            }
            .matches(in: input.description)

        guard action != nil || !matches.isEmpty else { return nil }

        return ParsedCreatureAction(
            action: action,
            diceExpressions: matches
        )
    }
}

struct ParsedCreatureAction: Codable, Hashable {
    let action: CreatureActionParser.Action?
    let diceExpressions: [Located<DiceExpression>]
}
