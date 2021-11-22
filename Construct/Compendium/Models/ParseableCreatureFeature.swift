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

    var attributedName: AttributedString {
        guard let parsed = result?.value else { return AttributedString(description) }

        var result = AttributedString(name)
        for annotation in parsed.nameAnnotations {
            result.apply(annotation)
        }

        return result
    }

    var attributedDescription: AttributedString {
        guard let parsed = result?.value else { return AttributedString(description) }

        var result = AttributedString(description)
        for annotation in parsed.descriptionAnnotations {
            result.apply(annotation)
        }

        return result
    }
}

struct CreatureFeatureDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureFeature) -> ParsedCreatureFeature? {
        return ParsedCreatureFeature(
            limitedUse: limitedUseInNameParser().run(input.name.lowercased()),
            spellcasting: input.name.lowercased().contains("spellcasting").compactMapTrue {
                var spellcasting = spellcastingParser().run(input.description.lowercased())
                spellcasting?.innate = input.name.lowercased().contains("innate")
                return spellcasting
            },
            otherDescriptionAnnotations: DiceExpressionParser.matches(in: input.description).map {
                $0.map { TextAnnotation.diceExpression($0) }
            }
        )
    }

    static func limitedUseInNameParser() -> Parser<Located<LimitedUse>> {
        either(
            zip(
                int(),
                string("/day")
            ).withRange().map { (val, range) in
                Located(value: LimitedUse(amount: val.0, recharge: .day), range: Range(range))
            },
            zip(
                string("recharge "),
                zip(
                    int(),
                    string("-")
                ).optional(),
                int()
            ).withRange().map { (val, range) in
                let (_, optLower, upper) = val
                let lower = optLower?.0 ?? upper
                return Located(value: LimitedUse(amount: 1, recharge: .turnStart([lower, upper])), range: Range(range))
            },
            string("recharge after a short or long rest").withRange().map { _, range in
                Located(value: LimitedUse(amount: 1, recharge: .rest(short: true, long: true)), range: Range(range))
            },
            string("recharge after a long rest").withRange().map { _, range in
                Located(value: LimitedUse(amount: 1, recharge: .rest(short: false, long: true)), range: Range(range))
            }
        ).skippingAnyBefore()
    }
}

struct ParsedCreatureFeature: Codable, Hashable {

    /**
     Parsed from `name`. Range is scoped to `name`.
     */
    let limitedUse: Located<LimitedUse>?
    let spellcasting: Spellcasting?

    let otherDescriptionAnnotations: [Located<TextAnnotation>]?

    var nameAnnotations: [Located<TextAnnotation>] {
        limitedUse.flatMap { llu in
            guard case .turnStart = llu.value.recharge else { return nil }
            return [llu.map { _ in TextAnnotation.diceExpression(1.d(6)) }]
        } ?? []
    }

    var descriptionAnnotations: [Located<TextAnnotation>] {
        var result: [Located<TextAnnotation>] = otherDescriptionAnnotations ?? []

        if let s = spellcasting {
            if let spellsByLevel = s.spellsByLevel {
                for (_, spells) in spellsByLevel {
                    result.append(contentsOf: spells.map { $0.map { .reference(.compendiumItem($0)) } })
                }
            }
            if let spellsPerDay = s.spellsByUse {
                for (_, spells) in spellsPerDay {
                    result.append(contentsOf: spells.map { $0.map { .reference(.compendiumItem($0)) } })
                }
            }
        }

        return result
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
        var spellsByLevel: [Int: [Located<CompendiumItemTextAnnotationReference>]]?

        /**
         A key of `nil` means "at will"
         */
        var spellsByUse: [LimitedUse?: [Located<CompendiumItemTextAnnotationReference>]]?
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
    typealias Value = CompendiumItemTextAnnotationReference
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
        case spellsByUse(LimitedUse?, [Located<String>])
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

        let spellsByLevel = zip(
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

        let spellsByUse = zip(
            either(
                string("at will").map { _ in nil },
                zip(
                    int(),
                    string("/day each")
                ).map { n, _ in .init(amount: n, recharge: .day) }
            ),
            string(": "),
            spellList
        ).map { use, _, spells in
            F.spellsByUse(use, spells)
        }

        return any(either(
            spellcasterLevel,
            ability,
            save,
            hit,
            spellsByLevel,
            spellsByUse
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
                    spellsByLevel[level] = spells.map { $0.map { .init(name: $0, type: .spell, resolvedTo: nil) } }
                    result.spellsByLevel = spellsByLevel
                case let .spellsByUse(limitedUse, spells):
                    var spellsByUse = result.spellsByUse ?? [:]
                    spellsByUse[limitedUse] = spells.map { $0.map { .init(name: $0, type: .spell, resolvedTo: nil) } }
                    result.spellsByUse = spellsByUse
                }
            }
            return result
        }
    }
}
