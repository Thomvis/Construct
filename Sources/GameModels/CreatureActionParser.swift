//
//  CreatureActionParser.swift
//  Construct
//
//  Created by Thomas Visser on 31/08/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import Dice

public struct CreatureActionParser {
    public typealias Action = ParsedCreatureAction.Model

    public static func parse(_ string: String) -> Action? {
        Self.parseRaw(string)?.1
    }

    public static func parseRaw(_ string: String) -> (Remainder, Action)? {
        var remainder = Remainder(string.lowercased())
        guard let action = weaponAttackParser().parse(&remainder) else {
            return nil
        }
        return (remainder, Action.weaponAttack(action))
    }

    static func weaponAttackParser() -> Parser<Action.WeaponAttack> {
        return zip(
            skip(until: string(":")),
            whitespace(),
            zip(
                either(
                    char("+").map { _ in 1 },
                    char("-").map { _ in -1 }
                ),
                int(),
                whitespace(),
                string("to hit")
            ).map { sign, mod, _, _ in
                return Modifier(modifier: sign * mod)
            },
            zip(string(","), whitespace().optional()),
            many(
                element: either(
                    zip(
                        whitespace().optional(),
                        string("reach "),
                        int(),
                        whitespace(),
                        string("ft.")
                    ).map { _, _, r, _, _ in
                        Action.WeaponAttack.Range.reach(r)
                    },

                    zip(
                        whitespace().optional(),
                        string("range "),
                        int(),
                        zip(
                            whitespace().optional(),
                            char("/"),
                            whitespace().optional(),
                            int()
                        ).map { _, _, _, r in r }.optional(),
                        string(" ft"),
                        string(".").optional()
                    ).map { _, _, normal, long, _, _ in
                        Action.WeaponAttack.Range.range(normal, long)
                    }
                ),
                separator: oneOrMore(
                    either(
                        string(","),
                        string("or")
                    ).trimming(whitespace())
                ),
                terminator: .nothing
            ),
            skip(until: zip(string("."), whitespace())), // skipping  "one target"
            hitParser().optional()
        ).map {  _, _, modifier, _, ranges, _, effects in
            Action.WeaponAttack(
                hitModifier: modifier,
                ranges: ranges,
                effects: effects ?? []
            )
        }
    }

    static func hitParser() -> Parser<[Action.AttackEffect]> {
        zip(
            string("hit:").optional(),
            whitespace().optional(),
            effectsParser()
        ).map { _, _, effects in
            effects
        }
    }

    static func effectsParser() -> Parser<[Action.AttackEffect]> {
        many(
            element: either(
                // these must go before damageEffect even though they're
                versatileWeaponGripConditionedDamageEffectParser(),
                rangeConditionedDamageEffectParser(),

                damageEffectParser(),
                savingThrowConditionedEffectParser(),
                otherConditionedEffectParser(),
                otherEffectParser()

            ),
            separator: oneOrMore(
                either(
                    string(","),
                    string("and"),
                    string("plus"),
                    string(".")
                ).trimming(whitespace())
            ),
            terminator: .nothing
        ).map { $0.flatMap { $0 } }
    }

    /// 9 (2d6 + 2) piercing damage in melee or 5 (1d6 + 2) piercing damage at range
    static func rangeConditionedDamageEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            damageParser(),
            string("in melee or").trimming(whitespace()),
            damageParser(),
            string("at range").trimming(whitespace())
        ).map { md, _, rd, _ in
            [
                .init(conditions: .init(type: .melee), damage: [md]),
                .init(conditions: .init(type: .ranged), damage: [rd])
            ]
        }
    }

    static func savingThrowConditionedEffectParser() -> Parser<[Action.AttackEffect]> {
        either(
            zip(
                string("the target must make a").trimming(whitespace()),
                savingThrowParser(),
                string(",").optional().trimming(whitespace()),
                string("taking "),
                damageEffectParser(),
                string("on a failed save").trimming(whitespace()),
                zip(
                    string(",").optional(),
                    whitespace(),
                    string("or half as much damage on a successful one")
                ).optional()
            ).map { _, save, _, _, dmg, _, half in
                dmg.map {
                    apply($0) {
                        $0.conditions.savingThrow = .init(
                            ability: save.1,
                            dc: save.0,
                            saveEffect: half != nil ? .half : .none
                        )
                    }
                }
            },
            zip(
                string("the target").trimming(whitespace()),
                mustSucceedSavingThrowEffectParser().map { [$0] }
            ).map { $0.1 }
        )
    }

    static func versatileWeaponGripConditionedDamageEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            damageParser(),
            string(",").trimming(whitespace()).optional(),
            string("or").trimming(whitespace()),
            damageParser(),
            string("if used with two hands").trimming(whitespace()),
            either(
                string("in melee"),
                string("to make a melee attack")
            ).trimming(whitespace()).optional()
        ).map { ohd, _, _, thd, _, _ in
            [
                .init(conditions: .init(versatileWeaponGrip: .oneHanded), damage: [ohd]),
                .init(conditions: .init(versatileWeaponGrip: .twoHanded), damage: [thd])
            ]
        }
    }

    // "If the target is a ..."
    static func otherConditionedEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            string("if the target is").trimming(whitespace()),
            skip(until: string(",").trimming(whitespace())),
            zip(
                string("it").trimming(whitespace()),
                either(
                    mustSucceedSavingThrowEffectParser(),
                    thenEffectParser()
                )
            ).map { $0.1 }
        ).map { _, c, effect in
            var res = effect
            res.conditions.other = "the target is \(c.0)"
            return [res]
        }
    }

    /// Parses:
    /// - 7 (1d10 + 2) piercing damage
    /// - 7 (1d10 + 2) piercing damage plus 3 (1d6) poison damage
    static func damageEffectParser() -> Parser<[Action.AttackEffect]> {
        many(
            element: damageParser(),
            separator: oneOrMore(
                either(
                    string(","),
                    string("and"),
                    string("plus")
                ).trimming(whitespace())
            ),
            terminator: .nothing
        ).flatMap { dmgs in
            guard dmgs.count > 0 else { return nil }
            return [.init(damage: dmgs)]
        }
    }

    /// Parses:
    /// - the target is grappled
    static func otherEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            string("the target").trimming(whitespace()),
            thenEffectParser()
        ).map { _, effect in
            [effect]
        }
    }

    static func mustSucceedSavingThrowEffectParser() -> Parser<Action.AttackEffect> {
        zip(
            string("must succeed on a").trimming(whitespace()),
            savingThrowParser(),
            skip(until: string("or").trimming(whitespace())), // skip optional "against X",
            either(
                zip(
                    string("take").trimming(whitespace()),
                    damageParser()
                ).map { _, dmg in
                    Action.AttackEffect(damage: [dmg])
                },
                zip(
                    string("become").trimming(whitespace()),
                    word().flatMap {
                        CreatureCondition(rawValue: $0)
                    }
                ).map { _, c in Action.AttackEffect(condition: .init(condition: c, comment: nil)) },
                string("be knocked prone").map { _ in
                    Action.AttackEffect(condition: .init(condition: .prone, comment: nil))
                },
                skip(until: string(".").trimming(whitespace())).map {
                    Action.AttackEffect(other: $0.0)
                }
            )
        ).map { _, st, _, e in
            apply(e) {
                $0.conditions.savingThrow = .init(
                    ability: st.1,
                    dc: st.0,
                    saveEffect: .none
                )
            }
        }
    }

    static func thenEffectParser() -> Parser<Action.AttackEffect> {
        either(
            zip(
                string("takes").trimming(whitespace()),
                damageParser()
            ).map { _, dmg in
                Action.AttackEffect(damage: [dmg])
            },
            zip(
                either(
                    string("is"),
                    string("becomes")
                ).trimming(whitespace()),
                word().flatMap {
                    CreatureCondition(rawValue: $0)
                }.trimming(whitespace()),
                either(
                    zip(
                        string("("),
                        skip(until: string(")")),
                        skip(until: string("."))
                    ).map { $0.1.0 },
                    skip(until: string(".")).map { $0.0 }
                )
            ).map { _, c, d in
                Action.AttackEffect(condition: .init(condition: c, comment: d.nonEmptyString))
            },
            skip(until: string(".").trimming(whitespace())).map {
                Action.AttackEffect(other: $0.0)
            }
        )
    }

    /// Parses:
    /// - dc 12 constitution saving throw
    static func savingThrowParser() -> Parser<(Int, Ability)> {
        zip(
            string("dc "),
            int(),
            whitespace(),
            word().flatMap { Ability(rawValue: $0) },
            whitespace(),
            string("saving throw")
        ).map { _, dc, _, ab, _, _ in
            (dc, ab)
        }
    }

    static func damageParser() -> Parser<Action.AttackEffect.Damage> {
        zip(
            int(),
            zip(
                whitespace(),
                char("("),
                DiceExpressionParser.diceExpression(),
                char(")")
            ).map { _, _, expr, _ in expr }.optional(),
            whitespace(),
            word().flatMap { DamageType(rawValue: $0) },
            whitespace(),
            string("damage")
        ).map { stat, expr, _, type, _, _ in
            Action.AttackEffect.Damage(
                staticDamage: stat,
                damageExpression: expr,
                type: type
            )
        }
    }
}
