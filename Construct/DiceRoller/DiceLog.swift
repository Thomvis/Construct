//
//  DiceLog.swift
//  Construct
//
//  Created by Thomas Visser on 29/12/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged
import Combine

struct DiceLog {
    private let subject: PassthroughSubject<(RolledDiceExpression, RollDescription), Never> = .init()

    var rolls: AnyPublisher<(RolledDiceExpression, RollDescription), Never> {
        subject.eraseToAnyPublisher()
    }

    func didRoll(_ expression: RolledDiceExpression, roll: RollDescription) {
        subject.send((expression, roll))
    }
}

struct RollDescription: Hashable {
    var expression: DiceExpression
    var title: AttributedString

    static func custom(_ expression: DiceExpression) -> Self {
        RollDescription(
            expression: expression,
            title: AttributedString(expression.description)
        )
    }

    static func abilityCheck(_ modifier: Int, ability: Ability, skill: Skill? = nil, combatant: Combatant? = nil, environment: Environment) -> Self {
        .abilityCheck(modifier, ability: ability, skill: skill, creatureName: combatant?.discriminatedName, environment: environment)
    }

    static func abilityCheck(_ modifier: Int, ability: Ability, skill: Skill? = nil, creatureName: String? = nil, environment: Environment) -> Self {
        var title = AttributedString("\(environment.modifierFormatter.stringWithFallback(for: modifier))")

        title += AttributedString(" \(ability.localizedDisplayName)")

        if let skill = skill {
            title += AttributedString(" (\(skill.localizedDisplayName))")
        }

        title += AttributedString(" Check")

        if let creatureName = creatureName {
            title += AttributedString(" - \(creatureName)")
        }

        return RollDescription(
            expression: 1.d(20)+modifier,
            title: title
        )
    }
}

struct DiceLogEntry: Hashable {
    let id: Tagged<DiceLogEntry, UUID>
    let roll: RollDescription
    var results: [Result]

    struct Result: Hashable {
        let id: Tagged<Result, UUID>
        let type: ResultType

        let first: RolledDiceExpression
        let second: RolledDiceExpression?

        var effectiveResult: RolledDiceExpression {
            guard let second = second else { return first }

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

        enum ResultType: Hashable {
            case normal
            case disadvantage
            case advantage
        }
    }
}
