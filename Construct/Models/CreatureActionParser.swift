//
//  CreatureActionParser.swift
//  Construct
//
//  Created by Thomas Visser on 31/08/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

struct CreatureActionParser {
    public static func parse(_ string: String) -> Action? {
        weaponAttackParser(string).run(string.lowercased()).map {
            Action.weaponAttack($0)
        }
    }

    static func weaponAttackParser(_ input: String) -> Parser<Action.WeaponAttack> {
        return zip(
            either(
                string("melee").map { _ in Action.WeaponAttack.AttackType.melee },
                string("ranged").map { _ in Action.WeaponAttack.AttackType.ranged }
            ).log("type"),
            string("weapon attack").skippingAnyBefore().log("wa"),
            zip(
                either(
                    char("+").map { _ in 1 },
                    char("-").map { _ in -1 }
                ),
                int(),
                string("to hit").skippingAnyBefore()
            ).skippingAnyBefore().log("mod"),
            either(
                zip(
                    string("reach"),
                    int().skippingAnyBefore(),
                    string(" ft").skippingAnyBefore()
                ).skippingAnyBefore().map {
                    Action.WeaponAttack.Range.reach($0.1)
                }.log("reach"),
                zip(
                    string("range"),
                    int().skippingAnyBefore(),
                    zip(
                        char("/"),
                        int()
                    ).optional().skippingAnyBefore(),
                    string(" ft").skippingAnyBefore()
                ).skippingAnyBefore().map {
                    Action.WeaponAttack.Range.range($0.1, $0.2?.1)
                }.log("range")
            ),
            effectsParser()
        ).map {
            Action.WeaponAttack(
                type: $0.0,
                range: $0.3,
                hitModifier: Modifier(modifier: $0.2.0 * $0.2.1),
                effects: $0.4
            )
        }
    }

    static func effectsParser() -> Parser<[Action.ActionEffect]> {
        any(actionEffectParser())
    }

    static func actionEffectParser() -> Parser<Action.ActionEffect> {
        either(
            saveableDamageParser().map { Action.ActionEffect.saveableDamage($0) },
            damageParser().map { Action.ActionEffect.damage($0) }
        ).skippingAnyBefore()
    }

    static func damageParser() -> Parser<Action.ActionEffect.Damage> {
        zip(
            int().log("statdam"),
            zip(
                char("(").skippingAnyBefore().log("parenopen"),
                DiceExpressionParser.diceExpression().log("diceexpr"),
                char(")").log("parenclose")
            ).optional(),
            word().flatMap { DamageType(rawValue: $0) }.skippingAnyBefore().log("dmg type"),
            string("damage").skippingAnyBefore()
        ).map {
            Action.ActionEffect.Damage(
                staticDamage: $0.0,
                damageExpression: $0.1?.1,
                type: $0.2
            )
        }.log("dmg")
    }

    static func saveableDamageParser() -> Parser<Action.ActionEffect.SaveableDamage> {
        zip(
            string("dc ").log("dc"),
            int().log("dc int"),
            word().flatMap { Ability(rawValue: $0) }.skippingAnyBefore().log("ab"),
            zip(horizontalWhitespace(), string("saving throw").log("st")).map { $0.1 },
            damageParser().skippingAnyBefore().log("dmg"),
            string("on a failed save").skippingAnyBefore().log("fail"),
            skip(until: char(".")).flatMap {
                string("half as much damage").skippingAnyBefore().run($0.0) != nil
            }
        ).map {
            Action.ActionEffect.SaveableDamage(
                ability: $0.2,
                dc: $0.1,
                damage: $0.4,
                saveEffect: $0.6 ? .half : .none
            )
        }.log("Sdmg")
    }

    enum Action: Hashable, Codable {
        case weaponAttack(WeaponAttack)

        struct WeaponAttack: Hashable, Codable {
            let type: AttackType
            let range: Range
            let hitModifier: Modifier
            let effects: [ActionEffect]

            enum AttackType: Hashable, Codable {
                case melee
                case ranged
            }

            enum Range: Hashable, Codable {
                case reach(Int)
                case range(Int, Int?)
            }
        }

        enum ActionEffect: Hashable, Codable {
            case damage(Damage)
            case saveableDamage(SaveableDamage)

            struct Damage: Hashable, Codable {
                let staticDamage: Int
                let damageExpression: DiceExpression?
                let type: DamageType
            }

            struct SaveableDamage: Hashable, Codable {
                let ability: Ability
                let dc: Int
                let damage: Damage
                let saveEffect: SaveEffect
            }

            enum SaveEffect: Hashable, Codable {
                case none
                case half
            }
        }
    }
}
