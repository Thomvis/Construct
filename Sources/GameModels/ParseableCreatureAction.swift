//
//  ParseableCreatureAction.swift
//  Construct
//
//  Created by Thomas Visser on 16/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import Dice
import Tagged

public typealias ParseableCreatureAction = Parseable<CreatureAction, ParsedCreatureAction>

public struct ParsedCreatureAction: DomainModel, Codable, Hashable {

    public static let version: String = "3"

    /**
     Parsed from `name`. Range is scoped to `name`.
     */
    public let limitedUse: Located<LimitedUse>?

    // TODO: action could contain some annotations
    public let action: Model?
    public let otherDescriptionAnnotations: [Located<TextAnnotation>]?

    public var nameAnnotations: [Located<TextAnnotation>] {
        limitedUse.flatMap { llu in
            guard case .turnStart = llu.value.recharge else { return nil }
            return [llu.map { _ in TextAnnotation.diceExpression(1.d(6)) }]
        } ?? []
    }

    public var descriptionAnnotations: [Located<TextAnnotation>] {
        otherDescriptionAnnotations ?? []
    }

    /**
     Returns nil if all parameters are nil
     */
    public init?(
        limitedUse: Located<LimitedUse>?,
        action: Model?,
        otherDescriptionAnnotations: [Located<TextAnnotation>]?
    ) {
        guard limitedUse != nil || action != nil || otherDescriptionAnnotations?.nonEmptyArray != nil else { return nil }

        self.limitedUse = limitedUse
        self.action = action
        self.otherDescriptionAnnotations = otherDescriptionAnnotations
    }

    public enum Model: Hashable, Codable {
        case weaponAttack(WeaponAttack)

        public struct WeaponAttack: Hashable, Codable {
            public let hitModifier: Modifier
            public let conditionalHitModifiers: [ConditionalHitModifier]
            public let ranges: [Range]
            public let effects: [AttackEffect]

            public init(
                hitModifier: Modifier,
                conditionalHitModifiers: [ConditionalHitModifier] = [],
                ranges: [Range],
                effects: [AttackEffect]
            ) {
                self.hitModifier = hitModifier
                self.conditionalHitModifiers = conditionalHitModifiers
                self.ranges = ranges
                self.effects = effects
            }

            public struct ConditionalHitModifier: Hashable, Codable {
                public let hitModifier: Modifier
                public let condition: String

                public init(hitModifier: Modifier, condition: String) {
                    self.hitModifier = hitModifier
                    self.condition = condition
                }
            }

            public enum Range: Hashable, Codable {
                case reach(Int)
                case range(Int, Int?)

                public var isReach: Bool {
                    if case .reach = self {
                        return true
                    }
                    return false
                }

                public var isRange: Bool {
                    !isReach
                }
            }
        }

        public enum AttackType: Hashable, Codable {
            case melee
            case ranged
        }

        public struct AttackEffect: Hashable, Codable {
            public var conditions: Conditions
            public let damage: [Damage]
            public let condition: CreatureConditionEffect? // restrained, prone, etc.
            public let replacesDamage: Bool
            public let other: String?

            public init(
                conditions: Conditions = .init(),
                damage: [Damage] = [],
                condition: CreatureConditionEffect? = nil,
                replacesDamage: Bool = false,
                other: String? = nil
            ) {
                self.conditions = conditions
                self.damage = damage
                self.condition = condition
                self.replacesDamage = replacesDamage
                self.other = other
            }

            public struct Conditions: Hashable, Codable {
                public let type: AttackType?
                public var savingThrow: SavingThrow?
                public let versatileWeaponGrip: Grip?
                public var other: String?

                public init(type: AttackType? = nil, savingThrow: SavingThrow? = nil, versatileWeaponGrip: Grip? = nil, other: String? = nil) {
                    self.type = type
                    self.savingThrow = savingThrow
                    self.versatileWeaponGrip = versatileWeaponGrip
                    self.other = other
                }

                public struct SavingThrow: Hashable, Codable {
                    public let ability: Ability
                    public let dc: Int
                    public let saveEffect: SaveEffect
                    // E.g. "fails by 5 or more" -> 5
                    public let failureMargin: Int?

                    public init(
                        ability: Ability,
                        dc: Int,
                        saveEffect: SaveEffect,
                        failureMargin: Int? = nil
                    ) {
                        self.ability = ability
                        self.dc = dc
                        self.saveEffect = saveEffect
                        self.failureMargin = failureMargin
                    }

                    public enum SaveEffect: Hashable, Codable {
                        case none
                        case half
                    }
                }

                public enum Grip: Hashable, Codable {
                    case oneHanded
                    case twoHanded
                }
            }

            public struct Damage: Hashable, Codable {
                public let staticDamage: Int
                public let damageExpression: DiceExpression?
                public let type: DamageType
                public let alternativeTypes: [DamageType]

                public init(
                    staticDamage: Int,
                    damageExpression: DiceExpression?,
                    type: DamageType,
                    alternativeTypes: [DamageType] = []
                ) {
                    self.staticDamage = staticDamage
                    self.damageExpression = damageExpression
                    self.type = type
                    self.alternativeTypes = alternativeTypes
                }
            }

            public struct CreatureConditionEffect: Hashable, Codable {
                public let condition: CreatureCondition
                public let comment: String?

                public init(condition: CreatureCondition, comment: String? = nil) {
                    self.condition = condition
                    self.comment = comment
                }
            }
        }
    }
}

struct CreatureActionDomainParser: DomainParser {
    static let version: String = "3"

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
