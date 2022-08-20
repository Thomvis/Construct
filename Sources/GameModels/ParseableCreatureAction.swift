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

public typealias ParseableCreatureAction = Parseable<CreatureAction, ParsedCreatureAction>

public extension ParseableCreatureAction {
    var name: String { input.name }
    var description: String { input.description }

    var attributedName: AttributedString {
        guard let parsed = result?.value else { return AttributedString(name) }

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

public struct ParsedCreatureAction: Codable, Hashable {

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
    public init?(limitedUse: Located<LimitedUse>?, action: Model?, otherDescriptionAnnotations: [Located<TextAnnotation>]?) {
        guard limitedUse != nil || action != nil || otherDescriptionAnnotations?.nonEmptyArray != nil else { return nil }

        self.limitedUse = limitedUse
        self.action = action
        self.otherDescriptionAnnotations = otherDescriptionAnnotations
    }

    public enum Model: Hashable, Codable {
        case weaponAttack(WeaponAttack)

        public struct WeaponAttack: Hashable, Codable {
            public let type: AttackType
            public let range: Range
            public let hitModifier: Modifier
            public let effects: [ActionEffect]

            public init(type: AttackType, range: Range, hitModifier: Modifier, effects: [ActionEffect]) {
                self.type = type
                self.range = range
                self.hitModifier = hitModifier
                self.effects = effects
            }

            public enum AttackType: Hashable, Codable {
                case melee
                case ranged
            }

            public enum Range: Hashable, Codable {
                case reach(Int)
                case range(Int, Int?)
            }
        }

        public enum ActionEffect: Hashable, Codable {
            case damage(Damage)
            case saveableDamage(SaveableDamage)

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

            public struct SaveableDamage: Hashable, Codable {
                public let ability: Ability
                public let dc: Int
                public let damage: Damage
                public let saveEffect: SaveEffect

                public init(ability: Ability, dc: Int, damage: Damage, saveEffect: SaveEffect) {
                    self.ability = ability
                    self.dc = dc
                    self.damage = damage
                    self.saveEffect = saveEffect
                }
            }

            public enum SaveEffect: Hashable, Codable {
                case none
                case half
            }
        }
    }

}


