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

struct DiceAction: Hashable {
    let title: String
    let subtitle: String
    var steps: IdentifiedArray<UUID, Step>

    struct Step: Hashable, Identifiable {
        let id = UUID()
        let title: String
        var value: Value?

        enum Value: Hashable {
            case roll(RollValue)

            struct RollValue: Hashable {
                let roll: Roll
                var type: RollType = .normal

                var first: AnimatedRollState = AnimatedRollState(expression: nil, result: nil, intermediaryResult: nil)
                var second: AnimatedRollState? = nil

                var details: Details?

                var expression: DiceExpression {
                    switch roll {
                    case .abilityCheck(let m): return 1.d(20) + m
                    case .other(let e): return e
                    }
                }

                var isAbilityCheck: Bool {
                    guard case .abilityCheck = roll else { return false }
                    return true
                }

                func animatedRollState(for roll: Details) -> AnimatedRollState? {
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

                enum Roll: Hashable {
                    case abilityCheck(Int)
                    case other(DiceExpression)
                }

                enum RollType: Hashable {
                    case normal
                    case disadvantage
                    case advantage
                }

                enum Details: Hashable {
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

        var rollDetails: DiceCalculatorState? {
            get {
                if case .roll(let v) = value, let detailRoll = v.details, let roll = detailRoll.isFirstRoll ? v.first : v.second {
                    return DiceCalculatorState(
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
    init?(title: String, parsedAction: ParsedCreatureAction.Model, env: Environment) {
        guard case .weaponAttack(let attack) = parsedAction else { return nil }

        self.init(
            title: title,
            subtitle: "\(attack.type == .melee ? "Melee" : "Ranged") weapon attack",
            steps: IdentifiedArray(uniqueElements: [
                Step(
                    title: "\(env.modifierFormatter.stringWithFallback(for: attack.hitModifier.modifier)) to hit",
                    value: .roll(Step.Value.RollValue(roll: .abilityCheck(attack.hitModifier.modifier)))
                )
            ] + attack.effects.flatMap { effect -> [Step] in
                switch effect {
                case .damage(let dmg):
                    return [Step(damage: dmg)]
                case .saveableDamage(let save):
                    return [
                        Step(
                            title: "DC \(save.dc) \(save.ability.localizedDisplayName) Saving Throw",
                            value: nil
                        ),
                        Step(damage: save.damage)
                    ]
                }
            })
        )
    }
}

extension DiceAction.Step {
    init(damage: ParsedCreatureAction.Model.ActionEffect.Damage) {
        self.init(
            title: "\(damage.staticDamage)" + (damage.damageExpression.map { " (\($0))" } ?? "") + " \(damage.type) damage",
            value: .roll(Value.RollValue(roll: .other(damage.damageExpression ?? .number(damage.staticDamage))))
        )
    }
}
