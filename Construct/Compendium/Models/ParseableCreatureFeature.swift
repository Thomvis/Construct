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

        for ref in parsed.compendiumItemReferences {
            result.apply(ref) { str, ref in
                str.construct.compendiumItemReference = ref
            }
        }

        return result
    }
}

struct CreatureFeatureDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureFeature) -> ParsedCreatureFeature? {
        let freeformMatches = DiceExpressionParser.diceExpression()
            .flatMap {
                // filter out expressions that are just a number
                $0.diceCount > 0 ? $0 : nil
            }
            .matches(in: input.description).nonEmptyArray

        if input.name.lowercased().contains("spellcasting"), var spellcasting = spellcastingParser().run(input.description.lowercased()) {
            spellcasting.freeform = freeformMatches.map(ParsedCreatureFeature.Freeform.init)
            return .spellcasting(spellcasting)
        } else if let freeformMatches = freeformMatches {
            return .freeform(ParsedCreatureFeature.Freeform(expressions: freeformMatches))
        }

        return nil
    }
}

enum ParsedCreatureFeature: Codable, Hashable {

    case spellcasting(Spellcasting)
    case freeform(Freeform)

    var diceExpressions: [Located<DiceExpression>] {
        switch self {
        case .spellcasting(let s): return s.freeform?.expressions ?? []
        case .freeform(let f): return f.expressions
        }
    }

    var compendiumItemReferences: [Located<String>] {
        switch self {
        case .spellcasting(let s):
            var result: [Located<String>] = []
            if let spellsByLevel = s.spellsByLevel {
                for (_, spells) in spellsByLevel {
                    result.append(contentsOf: spells)
                }
            }
            if let spellsPerDay = s.spellsPerDay {
                for (_, spells) in spellsPerDay {
                    result.append(contentsOf: spells)
                }
            }
            return result
        case .freeform: return []
        }
    }
}

extension ParsedCreatureFeature {
    struct Spellcasting: Hashable, Codable {
        var innate: Bool
        var spellcasterLevel: Int?
        var ability: Ability?
        var spellSaveDC: Int?
        var spellAttackHit: Modifier?

        var slotsByLevel: [Int:Int]?
        var spellsByLevel: [Int: [Located<String>]]?

        var spellsPerDay: [Int: [Located<String>]]?

        var freeform: Freeform?
    }

    struct Freeform: Hashable, Codable {
        let expressions: [Located<DiceExpression>]
    }
}

struct DiceExpressionAttribute: CodableAttributedStringKey {
    typealias Value = DiceExpression
    static let name = "DiceExpression"
}

struct CompendiumItemReferenceAttribute: CodableAttributedStringKey {
    typealias Value = String // FIXME
    static let name = "CompendiumItemReference"
}

extension AttributeScopes {
    struct ConstructAttributeScope: AttributeScope {
        let diceExpression: DiceExpressionAttribute
        let compendiumItemReference: CompendiumItemReferenceAttribute
    }

    var construct: ConstructAttributeScope.Type { ConstructAttributeScope.self }
}

extension CreatureFeatureDomainParser {
    enum ParsedSpellcastingFragment {
        case spellcasterLevel(Int)
        case ability(Ability)
        case save(Int)
        case hit(Modifier)
        case spellsByLevel(Int, Int?, [Located<String>])
        case spellsPerDay(Int, [Located<String>])
    }

    static func spellcastingParser() -> Parser<ParsedCreatureFeature.Spellcasting> {
        typealias F = ParsedSpellcastingFragment

        let spellcasterLevel = zip(
            int(),
            any(character { $0.isLetter }),
            string("-level spellcaster")
        ).map { l, _, _ in F.spellcasterLevel(l) }

        let ability = zip(
            string("spellcasting ability is "),
            word()
        ).flatMap { _, a in
            Ability(rawValue: a)
        }.map(F.ability)

        let save = zip(
            string("spell save dc "),
            int()
        ).map { _, dc in F.save(dc) }

        let modifier = zip(
            either(
                char("+").map { _ in 1 },
                char("-").map { _ in -1 }
            ),
            int()
        ).map { op, int in
            Modifier(modifier: op*int)
        }

        let hit = zip(
            modifier,
            string(" to hit with spell attacks")
        ).map { m, _ in F.hit(m) }

        let spellList = any(
            zip(
                oneOrMore(zip(word(), horizontalWhitespace().optional()).map { $0.0 }).joined(separator: " ")
                    .withRange()
                    .map {
                        Located(value: $0.0, range: Range($0.1))
                    },
                string(",").trimming(horizontalWhitespace()).optional()
            ).map { $0.0 }
        )

        let level = zip(
            either(
                string("cantrips").map { _ in 0 },
                zip(
                    int(),
                    word(), // st, nd, rd
                    string(" level")
                ).map { l, _, _ in l }
            ),
            string(" ("),
            either(
                string("at will").map { _ in nil },
                zip(
                    int(),
                    string(" slot"),
                    word().optional()
                ).map { i, _, _ in Optional(i) }
            ),
            string("): "),
            spellList
        ).map { level, _, slots, _, spells in
            F.spellsByLevel(level, slots, spells)
        }

        return any(either(
            spellcasterLevel,
            ability,
            save,
            hit,
            level
        ).skippingAnyBefore()).map { fragments in
            var result = ParsedCreatureFeature.Spellcasting(innate: false)
            for f in fragments {
                switch f {
                case .spellcasterLevel(let l): result.spellcasterLevel = l
                case .ability(let a): result.ability = a
                case .save(let dc): result.spellSaveDC = dc
                case .hit(let m): result.spellAttackHit = m
                case let .spellsByLevel(level, slots, spells):
                    if let slots = slots {
                        var slotsByLevel = result.slotsByLevel ?? [:]
                        slotsByLevel[level] = slots
                        result.slotsByLevel = slotsByLevel
                    }
                    var spellsByLevel = result.spellsByLevel ?? [:]
                    spellsByLevel[level] = spells
                    result.spellsByLevel = spellsByLevel
                case let .spellsPerDay(perDay, spells):
                    var spellsPerDay = result.spellsPerDay ?? [:]
                    spellsPerDay[perDay] = spells
                    result.spellsPerDay = spellsPerDay
                }
            }
            return result
        }
    }
}
