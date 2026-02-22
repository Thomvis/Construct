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
        let normalized = string.lowercased()

        var remainder = Remainder(normalized)
        if let action = weaponAttackParser().parse(&remainder) {
            return (remainder, Action.weaponAttack(action))
        }

        if let savingThrowAction = parseSavingThrowAction(normalized) {
            return (Remainder(""), .savingThrow(savingThrowAction))
        }

        return nil
    }

    static func weaponAttackParser() -> Parser<Action.WeaponAttack> {
        zip(
            skip(until: string(":")),
            whitespace(),
            hitModifierParser(),
            zip(string(","), whitespace().optional()).optional(),
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
            zip(
                string(","),
                whitespace().optional(),
                skip(until: zip(string("."), whitespace()))
            ).optional(), // skipping "one target"
            hitParser().optional()
        ).map {  _, _, hit, _, ranges, _, effects in
            Action.WeaponAttack(
                hitModifier: hit.0,
                conditionalHitModifiers: hit.1,
                ranges: ranges,
                effects: effects ?? []
            )
        }
    }

    static func hitModifierParser() -> Parser<(Modifier, [Action.WeaponAttack.ConditionalHitModifier])> {
        zip(
            signedModifierParser(),
            zip(
                whitespace(),
                string("to hit")
            ).optional(),
            zip(
                whitespace().optional(),
                char("("),
                skip(until: char(")"))
            ).map { _, _, inside in inside.0 }.optional()
        ).map { modifier, _, conditional in
            (
                modifier,
                conditional.map(Self.parseConditionalHitModifiers(from:)) ?? []
            )
        }
    }

    static func signedModifierParser() -> Parser<Modifier> {
        zip(
            either(
                char("+").map { _ in 1 },
                char("-").map { _ in -1 }
            ),
            int()
        ).map { sign, mod in
            Modifier(modifier: sign * mod)
        }
    }

    static func parseConditionalHitModifiers(from string: String) -> [Action.WeaponAttack.ConditionalHitModifier] {
        let pattern = #"([+-]\d+)\s*to hit(?:\s*with\s*([^,;]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.matches(in: string, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let modifierRange = Range(match.range(at: 1), in: string),
                  let modifierValue = Int(string[modifierRange])
            else {
                return nil
            }

            let condition: String
            if match.numberOfRanges >= 3,
               let conditionRange = Range(match.range(at: 2), in: string) {
                condition = "with \(string[conditionRange])"
            } else {
                condition = "conditional"
            }

            return .init(
                hitModifier: Modifier(modifier: modifierValue),
                condition: condition
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
                conditionalAlternativeDamageEffectParser(),
                replacementDamageEffectParser(),
                damageEffectParser(),
                savingThrowConditionedEffectParser()
            )
            .or(otherConditionedEffectParser())
            .or(otherEffectParser())
            .or(fallbackRemainderEffectParser()),
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

    /// - 14 (4d6) piercing damage, or 7 (2d6) piercing damage if the swarm has half of its hit points or fewer
    /// - 6 (1d8 + 2) piercing damage, or 11 (2d8 + 2) piercing damage while enlarged
    static func conditionalAlternativeDamageEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            damageParser(),
            string(",").trimming(whitespace()).optional(),
            string("or").trimming(whitespace()),
            damageParser(),
            alternativeDamageConditionParser()
        ).map { defaultDamage, _, _, conditionedDamage, condition in
            [
                .init(damage: [defaultDamage]),
                .init(conditions: .init(other: condition), damage: [conditionedDamage])
            ]
        }
    }

    static func alternativeDamageConditionParser() -> Parser<String> {
        either(
            string("with shillelagh or if wielded with two hands"),
            string("if the swarm has half of its hit points or fewer"),
            string("while enlarged"),
            string("in small or medium form"),
            string("with shillelagh"),
            string("if wielded with two hands")
        ).trimming(whitespace())
    }

    /// - Instead of dealing damage, the vampire can grapple the target (escape DC 18)
    static func replacementDamageEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            string("instead of dealing damage").trimming(whitespace()),
            string(",").trimming(whitespace()).optional(),
            skip(until: string("grapple the target").trimming(whitespace())),
            zip(
                whitespace().optional(),
                char("("),
                skip(until: char(")"))
            ).map { _, _, inner in inner.0 }.optional()
        ).map { _, _, _, comment in
            [
                .init(
                    condition: .init(condition: .grappled, comment: comment),
                    replacesDamage: true
                )
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
                effectSubjectParser(),
                mustSucceedSavingThrowEffectsParser()
            ).map { subject, effects in
                effects.map { effect in
                    guard subject == "the target" else {
                        return apply(effect) { $0.conditions.other = subject }
                    }
                    return effect
                }
            }
        )
    }

    static func mustSucceedSavingThrowEffectsParser() -> Parser<[Action.AttackEffect]> {
        zip(
            mustSucceedSavingThrowEffectParser(),
            failureMarginSavingThrowRiderParser().optional()
        ).map { primary, failureRider in
            var effects = [primary]

            if let failureRider, let primarySave = primary.conditions.savingThrow {
                effects.append(
                    apply(failureRider.effect) {
                        $0.conditions.savingThrow = .init(
                            ability: primarySave.ability,
                            dc: primarySave.dc,
                            saveEffect: .none,
                            failureMargin: failureRider.failureMargin
                        )
                    }
                )
            }

            return effects
        }
    }

    static func failureMarginSavingThrowRiderParser() -> Parser<(failureMargin: Int, effect: Action.AttackEffect)> {
        zip(
            string(".").optional().trimming(whitespace()),
            string("if the saving throw fails by").trimming(whitespace()),
            int(),
            string("or more").trimming(whitespace()),
            string(",").optional().trimming(whitespace()),
            effectSubjectParser(),
            thenEffectParser()
        ).map { _, _, margin, _, _, _, effect in
            (
                failureMargin: margin,
                effect: effect
            )
        }
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
                either(
                    string("it"),
                    string("the target"),
                    string("the creature")
                ).trimming(whitespace()),
                either(
                    mustSucceedSavingThrowEffectsParser().flatMap { $0.first },
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
        zip(
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
            ),
            zip(
                whitespace().optional(),
                char("("),
                skip(until: char(")"))
            ).map { _, _, inner in "(\(inner.0))" }.optional()
        ).flatMap { dmgs, trailingComment in
            guard dmgs.count > 0 else { return nil }
            var effects = [Action.AttackEffect(damage: dmgs)]
            if let trailingComment {
                effects.append(.init(other: trailingComment))
            }
            return effects
        }
    }

    /// Parses:
    /// - the target is grappled
    static func otherEffectParser() -> Parser<[Action.AttackEffect]> {
        zip(
            effectSubjectParser(),
            thenEffectParser()
        ).map { subject, effect in
            var modified = effect
            if subject != "the target" {
                modified.conditions.other = subject
            }
            return [modified]
        }
    }

    static func effectSubjectParser() -> Parser<String> {
        either(
            string("the target"),
            string("the creature"),
            string("a swallowed creature")
        ).trimming(whitespace())
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
                string("has").trimming(whitespace()),
                string("the").trimming(whitespace()).optional(),
                word().flatMap {
                    CreatureCondition(rawValue: $0)
                }.trimming(whitespace()),
                string("condition").trimming(whitespace()),
                skip(until: string(".")).map { $0.0 }.optional()
            ).map { _, _, c, _, comment in
                Action.AttackEffect(
                    condition: .init(
                        condition: c,
                        comment: comment?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .nonEmptyString
                    )
                )
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

    static func fallbackRemainderEffectParser() -> Parser<[Action.AttackEffect]> {
        remainder().flatMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaningful = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            guard meaningful.nonEmptyString != nil else {
                return nil
            }

            return [.init(other: meaningful)]
        }
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
            zip(
                whitespace(),
                string("or"),
                whitespace(),
                word().flatMap { DamageType(rawValue: $0) }
            ).map { _, _, _, type in type }.optional(),
            whitespace(),
            string("damage")
        ).map { stat, expr, _, type, alternatives, _, _ in
            Action.AttackEffect.Damage(
                staticDamage: stat,
                damageExpression: expr,
                type: type,
                alternativeTypes: alternatives.map { [$0] } ?? []
            )
        }
    }

    static func parseSavingThrowAction(_ string: String) -> Action.SavingThrowAction? {
        let headerPattern = #"^(strength|dexterity|constitution|intelligence|wisdom|charisma)\s+saving throw:\s*dc\s+(\d+),\s*(.+?)\.\s*(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: headerPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(
                in: string,
                options: [],
                range: NSRange(location: 0, length: string.utf16.count)
              ),
              let abilityRange = Range(match.range(at: 1), in: string),
              let dcRange = Range(match.range(at: 2), in: string),
              let targetRange = Range(match.range(at: 3), in: string),
              let bodyRange = Range(match.range(at: 4), in: string),
              let ability = Ability(rawValue: String(string[abilityRange])),
              let dc = Int(string[dcRange])
        else {
            return nil
        }

        let target = String(string[targetRange]).trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyString
        let body = String(string[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let outcomeEffects = parseSavingThrowOutcomeEffects(body, dc: dc, ability: ability)

        guard !outcomeEffects.isEmpty else { return nil }

        return .init(
            savingThrow: .init(
                ability: ability,
                dc: dc,
                saveEffect: .none
            ),
            target: target,
            effects: outcomeEffects
        )
    }

    static func parseSavingThrowOutcomeEffects(
        _ body: String,
        dc: Int,
        ability: Ability
    ) -> [Action.SavingThrowAction.OutcomeEffect] {
        let labelPattern = #"(?i)\b(failure or success|first failure|second failure|failure|success)\b\s*:?\s*"#

        guard let regex = try? NSRegularExpression(pattern: labelPattern, options: []),
              let nsRange = Range(NSRange(location: 0, length: body.utf16.count), in: body)
        else {
            return []
        }

        let matches = regex.matches(
            in: body,
            options: [],
            range: NSRange(location: 0, length: body.utf16.count)
        )

        guard !matches.isEmpty else { return [] }

        var results: [Action.SavingThrowAction.OutcomeEffect] = []

        for (index, match) in matches.enumerated() {
            guard let labelRange = Range(match.range(at: 1), in: body),
                  let fullRange = Range(match.range(at: 0), in: body),
                  let outcome = parseSavingThrowOutcomeLabel(String(body[labelRange]))
            else {
                continue
            }

            let segmentStart = fullRange.upperBound
            let segmentEnd: String.Index
            if index + 1 < matches.count {
                guard let nextFullRange = Range(matches[index + 1].range(at: 0), in: body) else {
                    continue
                }
                segmentEnd = nextFullRange.lowerBound
            } else {
                segmentEnd = nsRange.upperBound
            }

            let segment = String(body[segmentStart..<segmentEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let parsedEffects = parseSavingThrowEffects(segment, dc: dc, ability: ability)

            guard !parsedEffects.isEmpty else { continue }

            results.append(.init(outcome: outcome, effects: parsedEffects))
        }

        return results
    }

    static func parseSavingThrowOutcomeLabel(
        _ label: String
    ) -> Action.SavingThrowAction.OutcomeEffect.Outcome? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "failure":
            return .failure
        case "success":
            return .success
        case "failure or success":
            return .failureOrSuccess
        case "first failure":
            return .firstFailure
        case "second failure":
            return .secondFailure
        default:
            return nil
        }
    }

    static func parseSavingThrowEffects(
        _ segment: String,
        dc: Int,
        ability: Ability
    ) -> [Action.AttackEffect] {
        guard segment.nonEmptyString != nil else { return [] }

        let normalizedSegment = normalizeConditionTypos(in: segment)

        var remainder = Remainder(normalizedSegment)
        if let parsed = effectsParser().parse(&remainder), !parsed.isEmpty {
            let trailing = remainder.string()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

            var results = parsed
            if let trailing = trailing.nonEmptyString {
                results.append(.init(other: trailing))
            }

            results = mergeSavingThrowNarrativeRiders(results)

            return results.map {
                apply($0) {
                    $0.conditions.savingThrow = .init(
                        ability: ability,
                        dc: dc,
                        saveEffect: .none
                    )
                }
            }
        }

        guard let fallback = segment
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\r.,;:"))
            .nonEmptyString
        else {
            return []
        }

        return [
            .init(
                conditions: .init(
                    savingThrow: .init(
                        ability: ability,
                        dc: dc,
                        saveEffect: .none
                    )
                ),
                other: fallback
            )
        ]
    }

    private static func normalizeConditionTypos(in value: String) -> String {
        value
            .replacingOccurrences(of: #"\bunconscious\b"#, with: "unconcious", options: .regularExpression)
            .replacingOccurrences(of: #"\bpoisoned\b"#, with: "poisioned", options: .regularExpression)
    }

    private static func mergeSavingThrowNarrativeRiders(
        _ effects: [Action.AttackEffect]
    ) -> [Action.AttackEffect] {
        var merged: [Action.AttackEffect] = []

        for effect in effects {
            let isOtherOnly =
                effect.damage.isEmpty
                && effect.condition == nil
                && effect.other?.nonEmptyString != nil
                && effect.conditions.type == nil
                && effect.conditions.savingThrow == nil
                && effect.conditions.versatileWeaponGrip == nil
                && effect.conditions.other == nil
                && !effect.replacesDamage

            if isOtherOnly,
               let rider = effect.other?.nonEmptyString,
               rider.lowercased().hasPrefix("this effect ends"),
               let last = merged.last,
               let lastCondition = last.condition
            {
                let combinedComment = [lastCondition.comment?.nonEmptyString, rider]
                    .compactMap { $0 }
                    .joined(separator: ". ")
                    .nonEmptyString

                merged[merged.count - 1] = .init(
                    conditions: last.conditions,
                    damage: last.damage,
                    condition: .init(condition: lastCondition.condition, comment: combinedComment),
                    replacesDamage: last.replacesDamage,
                    other: last.other
                )
                continue
            }

            merged.append(effect)
        }

        return merged
    }
}
