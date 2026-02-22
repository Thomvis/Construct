//
//  DiceAction.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Dice
import DiceRollerFeature
import GameModels
import Helpers

@ObservableState
public struct DiceAction: Hashable {
    let title: String
    let subtitle: String
    var steps: IdentifiedArrayOf<Step>

    @ObservableState
    public struct Step: Hashable, Identifiable {
        public let id = UUID()
        let title: String
        let subtitle: String?
        var value: Value?

        public enum Value: Hashable {
            case roll(RollValue)

            @ObservableState
            public struct RollValue: Hashable {
                let roll: Roll
                var type: RollType = .normal

                var first: AnimatedRoll.State = AnimatedRoll.State(expression: nil, result: nil, intermediaryResult: nil)
                var second: AnimatedRoll.State? = nil

                var details: Details?

                var expression: DiceExpression {
                    switch roll {
                    case .toHit(let m): return 1.d(20) + m.modifier
                    case .damage(let d): return d.damageExpression ?? .number(d.staticDamage)
                    }
                }

                var result: RolledDiceExpression? {
                    guard let first = first.result else { return nil }
                    guard let second = second?.result else { return first }

                    switch type {
                    case .disadvantage:
                        if second.total < first.total {
                            return second
                        }
                    case .advantage:
                        if second.total > first.total {
                            return second
                        }
                    default: break
                    }

                    return first
                }

                var isToHit: Bool {
                    guard case .toHit = roll else { return false }
                    return true
                }

                func animatedRollState(for roll: Details) -> AnimatedRoll.State? {
                    switch roll {
                    case .firstRoll: return first
                    case .secondRoll: return second
                    }
                }

                func emphasis(for roll: Details) -> RollType? {
                    guard let r = animatedRollState(for: roll)?.result, let o = animatedRollState(for: roll.other)?.result else { return nil }
                    switch type {
                    case .advantage where r.total > o.total: return .advantage
                    case .disadvantage where r.total < o.total: return .disadvantage
                    default: return nil
                    }
                }

                public enum Roll: Hashable {
                    case toHit(Modifier)
                    case damage(ParsedCreatureAction.Model.AttackEffect.Damage)
                }

                public enum RollType: Hashable {
                    case normal
                    case disadvantage
                    case advantage
                }

                public enum Details: Hashable {
                    case firstRoll
                    case secondRoll

                    var isFirstRoll: Bool {
                        switch self {
                        case .firstRoll: return true
                        case .secondRoll: return false
                        }
                    }

                    var other: Details {
                        switch self {
                        case .firstRoll: return .secondRoll
                        case .secondRoll: return .firstRoll
                        }
                    }
                }
            }
        }

        var rollValue: Value.RollValue? {
            get {
                if case .roll(let r) = value {
                    return r
                }
                return nil
            }
            set {
                if let r = newValue {
                    value = .roll(r)
                }
            }
        }

        var rollDetails: DiceCalculator.State? {
            get {
                if case .roll(let v) = value, let detailRoll = v.details, let roll = detailRoll.isFirstRoll ? v.first : v.second {
                    return DiceCalculator.State(
                        displayOutcomeExternally: false,
                        rollOnAppear: false,
                        expression: v.expression,
                        result: roll.result,
                        intermediaryResult: roll.intermediaryResult,
                        mode: .rollingExpression,
                        showDice: true
                    )
                }
                return nil
            }
            set {
                if let newValue = newValue {
                    if case .roll(let v) = value, let detailRoll = v.details {
                        if detailRoll.isFirstRoll {
                            rollValue?.first.result = newValue.result
                        } else {
                            rollValue?.second?.result = newValue.result
                        }
                    }
                }
            }
        }
    }
}

extension DiceAction {
    init?(title: String, parsedAction: ParsedCreatureAction.Model) {
        @Dependency(\.modifierFormatter) var modifierFormatter

        switch parsedAction {
        case .weaponAttack(let attack):
            self.init(
                title: title,
                subtitle: {
                    if attack.ranges.allSatisfy(\.isReach) {
                        return "Melee Weapon Attack"
                    } else if attack.ranges.allSatisfy(\.isRange) {
                        return "Ranged Weapon Attack"
                    } else {
                        return "Melee or Ranged Weapon Attack"
                    }
                }(),
                steps: IdentifiedArray(uniqueElements: [
                    Step(
                        title: "\(modifierFormatter.string(from: attack.hitModifier.modifier)) to hit",
                        subtitle: nil,
                        value: .roll(Step.Value.RollValue(roll: .toHit(attack.hitModifier)))
                    )
                ] + Self.steps(from: attack.effects))
            )
        case .savingThrow(let action):
            let saveText = "DC \(action.savingThrow.dc) \(action.savingThrow.ability.localizedDisplayName) save"
            let targetText = action.target?.nonEmptyString
            let outcomeSteps = action.effects.flatMap { outcome in
                Self.steps(
                    from: outcome.effects,
                    extraCondition: outcome.outcome.displayName,
                    includeSavingThrowCondition: false
                )
            }

            self.init(
                title: title,
                subtitle: "Saving Throw Action",
                steps: IdentifiedArray(
                    uniqueElements: [
                        Step(title: saveText, subtitle: targetText)
                    ] + outcomeSteps
                )
            )
        }
    }

    private static func steps(
        from effects: [ParsedCreatureAction.Model.AttackEffect],
        extraCondition: String? = nil,
        includeSavingThrowCondition: Bool = true
    ) -> [Step] {
        effects.flatMap { effect -> [Step] in
            var conditionComponents: [String] = []

            if let extraCondition {
                conditionComponents.append(extraCondition)
            }

            if effect.conditions.type == .melee {
                conditionComponents.append("melee")
            } else if effect.conditions.type == .ranged {
                conditionComponents.append("ranged")
            }

            if includeSavingThrowCondition, let save = effect.conditions.savingThrow {
                let saveDescription = "DC \(save.dc) \(save.ability.localizedDisplayName)"
                if effect.conditions.savingThrow?.saveEffect == .some(.none) {
                    conditionComponents.append("on a failed save (\(saveDescription))")
                } else if effect.conditions.savingThrow?.saveEffect == .half {
                    conditionComponents.append("on a failed save (\(saveDescription)), or halved otherwise")
                }
            }

            if effect.conditions.versatileWeaponGrip == .oneHanded {
                conditionComponents.append("one-handed")
            } else if effect.conditions.versatileWeaponGrip == .twoHanded {
                conditionComponents.append("two-handed")
            }

            if let other = effect.conditions.other?.nonEmptyString {
                conditionComponents.append(other)
            }

            let conds = conditionComponents.nonEmptyArray?.joined(separator: ", ")

            return Array<Step>(builder: {
                effect.damage.map { Step(damage: $0, subtitle: conds) }

                if let creatureCondition = effect.condition {
                    let title = "The target is \(creatureCondition.condition.localizedDisplayName)"
                    let condsAndComment = [
                        conds, creatureCondition.comment
                    ].compactMap { $0 }.nonEmptyArray?.joined(separator: ", ")
                    Step(title: title, subtitle: condsAndComment)
                }

                if let otherEffect = effect.other {
                    Step(title: otherEffect, subtitle: conds)
                }
            })
        }
    }
}

extension DiceAction.Step {
    init(
        damage: ParsedCreatureAction.Model.AttackEffect.Damage,
        subtitle: String?
    ) {
        self.init(
            title: "\(damage.staticDamage)"
                + (damage.damageExpression.map { " (\($0))" } ?? "") + " \(damage.type) damage",
            subtitle: subtitle,
            value: .roll(Value.RollValue(roll: .damage(damage)))
        )
    }
}
