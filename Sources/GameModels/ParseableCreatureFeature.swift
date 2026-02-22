//
//  ParseableCreatureFeature.swift
//  Construct
//
//  Created by Thomas Visser on 09/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Dice
import Helpers
import Tagged

public typealias ParseableCreatureFeature = Parseable<CreatureFeature, ParsedCreatureFeature>

public struct ParsedCreatureFeature: DomainModel, Codable, Hashable {

    public static let version: String = "3"

    /**
     Parsed from `name`. Range is scoped to `name`.
     */
    public let limitedUse: Located<LimitedUse>?
    public var spellcasting: Spellcasting?

    let otherDescriptionAnnotations: [Located<TextAnnotation>]?

    public init(
        limitedUse: Located<LimitedUse>? = nil,
        spellcasting: Spellcasting? = nil,
        otherDescriptionAnnotations: [Located<TextAnnotation>]? = nil
    ) {
        self.limitedUse = limitedUse
        self.spellcasting = spellcasting
        self.otherDescriptionAnnotations = otherDescriptionAnnotations
    }

    public var nameAnnotations: [Located<TextAnnotation>] {
        limitedUse.flatMap { llu in
            guard case .turnStart = llu.value.recharge else { return nil }
            return [llu.map { _ in TextAnnotation.diceExpression(1.d(6)) }]
        } ?? []
    }

    public var descriptionAnnotations: [Located<TextAnnotation>] {
        var result: [Located<TextAnnotation>] = otherDescriptionAnnotations ?? []

        if let s = spellcasting {
            if let spellsByLevel = s.spellsByLevel {
                for (_, spells) in spellsByLevel {
                    result.append(contentsOf: spells.map { $0.map { .reference(.compendiumItem($0)) } })
                }
            }
            if let limitedUseSpells = s.limitedUseSpells {
                for group in limitedUseSpells {
                    result.append(contentsOf: group.spells.map { $0.map { .reference(.compendiumItem($0)) } })
                }
            }
        }

        return result
    }
}

extension ParsedCreatureFeature {
    public struct Spellcasting: Hashable, Codable {
        public var innate: Bool
        public var spellcasterLevel: Int?
        public var ability: Ability?
        public var spellSaveDC: Int?
        public var spellAttackHit: Modifier?

        public var slotsByLevel: [Int:Int]?
        public var spellsByLevel: [Int: [Located<CompendiumItemReferenceTextAnnotation>]]?

        public var limitedUseSpells: [LimitedUseSpellGroup]?

        public init(
            innate: Bool,
            spellcasterLevel: Int? = nil,
            ability: Ability? = nil,
            spellSaveDC: Int? = nil,
            spellAttackHit: Modifier? = nil,
            slotsByLevel: [Int : Int]? = nil,
            spellsByLevel: [Int : [Located<CompendiumItemReferenceTextAnnotation>]]? = nil,
            limitedUseSpells: [LimitedUseSpellGroup]? = nil
        ) {
            self.innate = innate
            self.spellcasterLevel = spellcasterLevel
            self.ability = ability
            self.spellSaveDC = spellSaveDC
            self.spellAttackHit = spellAttackHit
            self.slotsByLevel = slotsByLevel
            self.spellsByLevel = spellsByLevel
            self.limitedUseSpells = limitedUseSpells
        }

        public struct LimitedUseSpellGroup: Hashable, Codable {
            public let spells: [Located<CompendiumItemReferenceTextAnnotation>]
            /**
             A value of `nil` means "at will"
             */
            public let limitedUse: LimitedUse?

            public init(
                spells: [Located<CompendiumItemReferenceTextAnnotation>],
                limitedUse: LimitedUse? = nil
            ) {
                self.spells = spells
                self.limitedUse = limitedUse
            }
        }
    }

    struct Freeform: Hashable, Codable {
        let expressions: [Located<DiceExpression>]
    }
}

public struct DiceExpressionAttribute: CodableAttributedStringKey {
    public typealias Value = DiceExpression
    public static let name = "DiceExpression"
}

public struct CompendiumItemReferenceAttribute: CodableAttributedStringKey {
    public typealias Value = CompendiumItemReferenceTextAnnotation
    public static let name = "CompendiumItemReference"
}

public extension AttributeScopes {
    struct ConstructAttributeScope: AttributeScope {
        public let diceExpression: DiceExpressionAttribute
        public let compendiumItemReference: CompendiumItemReferenceAttribute
    }

    var construct: ConstructAttributeScope.Type { ConstructAttributeScope.self }
}

struct CreatureFeatureDomainParser: DomainParser {
    static let version: String = "3"

    static func parse(input: CreatureFeature) -> ParsedCreatureFeature? {
        let normalizedName = input.name.lowercased()
        let normalizedDescription = input.description.lowercased()
        let isSpellcastingFeature = normalizedName.contains("spellcasting")
            || normalizedDescription.contains("spellcasting ability")

        return ParsedCreatureFeature(
            limitedUse: limitedUseInNameParser().run(normalizedName),
            spellcasting: isSpellcastingFeature.compactMapTrue {
                var spellcasting = spellcastingParser().run(normalizedDescription)
                spellcasting?.innate = normalizedName.contains("innate")
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
            string("recharges after a short or long rest").withRange().map { _, range in
                Located(value: LimitedUse(amount: 1, recharge: .rest(short: true, long: true)), range: Range(range))
            },
            string("recharges after a long rest").withRange().map { _, range in
                Located(value: LimitedUse(amount: 1, recharge: .rest(short: false, long: true)), range: Range(range))
            }
        ).skippingAnyBefore()
    }
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
                either(
                    string("cantrips"),
                    string("cantrip")
                ).map { _ in 0 },
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
                    string("e").optional(),
                    string("/day each")
                ).map { n, _, _ in .init(amount: n, recharge: .day) }
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
                    spellsByLevel[level] = spells.map { $0.map { .init(text: $0, type: .spell) } }
                    result.spellsByLevel = spellsByLevel
                case let .spellsByUse(limitedUse, spells):
                    var limitedUseSpells = result.limitedUseSpells ?? []
                    for spell in spells {
                        let locatedAnnotation = spell.map { CompendiumItemReferenceTextAnnotation(text: $0, type: .spell) }
                        limitedUseSpells.append(.init(spells: [locatedAnnotation], limitedUse: limitedUse))
                    }
                    result.limitedUseSpells = limitedUseSpells
                }
            }
            return result
        }
    }
}
