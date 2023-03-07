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

    public static let version: String = "2"

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
            public let ranges: [Range]
            public let effects: [AttackEffect]

            public init(hitModifier: Modifier, ranges: [Range], effects: [AttackEffect]) {
                self.hitModifier = hitModifier
                self.ranges = ranges
                self.effects = effects
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
            public let condition: CreatureCondition? // restrained, prone, etc.
            public let other: String?

            public init(
                conditions: Conditions = .init(),
                damage: [Damage] = [],
                condition: CreatureCondition? = nil,
                other: String? = nil
            ) {
                self.conditions = conditions
                self.damage = damage
                self.condition = condition
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

                    public init(ability: Ability, dc: Int, saveEffect: SaveEffect) {
                        self.ability = ability
                        self.dc = dc
                        self.saveEffect = saveEffect
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

                public init(staticDamage: Int, damageExpression: DiceExpression?, type: DamageType) {
                    self.staticDamage = staticDamage
                    self.damageExpression = damageExpression
                    self.type = type
                }
            }
        }
    }

}
