//
//  CompendiumParseableVisitor.swift
//  Construct
//
//  Created by Thomas Visser on 15/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import CasePaths
import Helpers
import GameModels
import Helpers

extension CompendiumEntry: HasParseableVisitor {
    public static let parseableVisitor: ParseableVisitor<CompendiumEntry> = .combine(
        Monster.parseableVisitor.ifSome().pullback(state: \.monster, action: CasePath.`self`),
        Character.parseableVisitor.ifSome().pullback(state: \.character, action: CasePath.`self`),
        Spell.parseableVisitor.ifSome().pullback(state: \.spell, action: CasePath.`self`)
    )

    var monster: Monster? {
        get {
            item as? Monster
        }
        set {
            if let newValue = newValue {
                item = newValue
            }
        }
    }

    var character: Character? {
        get {
            item as? Character
        }
        set {
            if let newValue = newValue {
                item = newValue
            }
        }
    }

    var spell: Spell? {
        get {
            item as? Spell
        }
        set {
            if let newValue = newValue {
                item = newValue
            }
        }
    }
}

extension Monster {
    static let parseableVisitor: ParseableVisitor<Monster> = .combine(
        StatBlock.parseableVisitor.pullback(state: \.stats, action: CasePath.`self`)
    )
}

extension Character {
    static let parseableVisitor: ParseableVisitor<Character> = .combine(
        StatBlock.parseableVisitor.pullback(state: \.stats, action: CasePath.`self`)
    )
}

extension Spell {
    static let parseableVisitor: ParseableVisitor<Spell> = ParseableVisitor { spell in
        spell.description.parseIfNeeded()
    }
}

extension StatBlock {
    static let parseableVisitor: ParseableVisitor<StatBlock> = ParseableVisitor { statBlock in
        for i in statBlock.features.indices {
            statBlock.features[i].parseIfNeeded()
        }

        for i in statBlock.actions.indices {
            statBlock.actions[i].parseIfNeeded()
        }

        for i in statBlock.reactions.indices {
            statBlock.reactions[i].parseIfNeeded()
        }

        for i in (statBlock.legendary?.actions.indices ?? [].indices) {
            statBlock.legendary?.actions[i].parseIfNeeded()
        }
    }
}

extension ParseableCreatureAction {
    mutating func parseIfNeeded() {
        parseIfNeeded(parser: CreatureActionDomainParser.self)
    }
}

extension ParseableCreatureFeature {
    mutating func parseIfNeeded() {
        parseIfNeeded(parser: CreatureFeatureDomainParser.self)
    }
}

extension ParseableSpellDescription {
    mutating func parseIfNeeded() {
        parseIfNeeded(parser: SpellDescriptionDomainParser.self)
    }
}

struct CreatureActionDomainParser: DomainParser {
    static let version: String = "1"

    static func parse(input: CreatureAction) -> ParsedCreatureAction? {
        return ParsedCreatureAction(
            limitedUse: CreatureFeatureDomainParser.limitedUseInNameParser().run(input.name.lowercased()),
            action: CreatureActionParser.parse(input.description),
            otherDescriptionAnnotations: DiceExpressionParser.matches(in: input.description).map {
                $0.map { TextAnnotation.diceExpression($0) }
            }
        )
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
