//
//  ParseableCreatureFeature.swift
//  Construct
//
//  Created by Thomas Visser on 09/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

typealias ParseableCreatureFeature = Parseable<CreatureFeature, ParsedCreatureFeature, CreatureFeatureDomainParser>

extension ParseableCreatureFeature {
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

struct CreatureFeatureDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureFeature) -> ParsedCreatureFeature? {
        let matches = DiceExpressionParser.diceExpression()
            .flatMap {
                // filter out expressions that are just a number
                $0.diceCount > 0 ? $0 : nil
            }
            .matches(in: input.description)

        guard !matches.isEmpty else { return nil }
        return .freeform(ParsedCreatureFeature.Freeform(expressions: matches))
    }
}

enum ParsedCreatureFeature: Codable, Hashable {

    case spellcasting(Spellcasting)
    case freeform(Freeform)

    // TODO: add other "annotation" types
    var diceExpressions: [Located<DiceExpression>] {
        switch self {
        case .spellcasting: return []
        case .freeform(let f): return f.expressions
        }
    }
}

extension ParsedCreatureFeature {
    struct Spellcasting: Hashable, Codable {
        let innate: Bool
        let ability: Ability?
        let slotsByLevel: [Int:Int]
        let spells: [Located<String>]
    }

    struct Freeform: Hashable, Codable {
        let expressions: [Located<DiceExpression>]
    }
}

struct SpellReference {
    let name: String
    let ref: CompendiumItemReference
}

struct DiceExpressionAttribute: CodableAttributedStringKey {
    typealias Value = DiceExpression
    static let name = "DiceExpression"
}

extension AttributeScopes {
    struct ConstructAttributeScope: AttributeScope {
        let diceExpression: DiceExpressionAttribute
    }

    var construct: ConstructAttributeScope.Type { ConstructAttributeScope.self }
}
