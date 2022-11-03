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

public extension ParseableCreatureFeature {
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

public struct ParsedCreatureFeature: DomainModel, Codable, Hashable {

    public static let version: String = "2"

    public let id: Id

    /**
     Parsed from `name`. Range is scoped to `name`.
     */
    public let limitedUse: Located<LimitedUse>?
    public let spellcasting: Spellcasting?

    let otherDescriptionAnnotations: [Located<TextAnnotation>]?

    public init(
        id: Id = UUID().tagged(),
        limitedUse: Located<LimitedUse>? = nil,
        spellcasting: Spellcasting? = nil,
        otherDescriptionAnnotations: [Located<TextAnnotation>]? = nil
    ) {
        self.id = id
        self.limitedUse = limitedUse
        self.spellcasting = spellcasting
        self.otherDescriptionAnnotations = otherDescriptionAnnotations
    }

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
            if let limitedUseSpells = s.limitedUseSpells {
                for group in limitedUseSpells {
                    result.append(contentsOf: group.spells.map { $0.map { .reference(.compendiumItem($0)) } })
                }
            }
        }

        return result
    }

    public typealias Id = Tagged<ParsedCreatureFeature, UUID>
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
