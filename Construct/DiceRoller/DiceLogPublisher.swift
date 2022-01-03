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

struct DiceLogPublisher {
    private let subject: PassthroughSubject<(DiceLogEntry.Result, RollDescription), Never> = .init()

    var rolls: AnyPublisher<(DiceLogEntry.Result, RollDescription), Never> {
        subject.eraseToAnyPublisher()
    }

    func didRoll(_ expression: RolledDiceExpression, roll: RollDescription) {
        didRoll(DiceLogEntry.Result(id: UUID().tagged(), type: .normal, first: expression, second: nil), roll: roll)
    }

    func didRoll(_ result: DiceLogEntry.Result, roll: RollDescription) {
        subject.send((result, roll))
    }
}

struct DiceLog: Hashable {
    var entries: [DiceLogEntry] = []

    mutating func receive(_ result: DiceLogEntry.Result, for roll: RollDescription) {
        let result: DiceLogEntry.Result = .init(
            id: UUID().tagged(),
            type: result.type,
            first: result.first,
            second: result.second
        )

        if entries.last?.roll == roll {
            entries[entries.endIndex-1].results.append(result)
        } else {
            entries.append(DiceLogEntry(
                id: UUID().tagged(),
                roll: roll,
                results: [
                    result
                ]
            ))
        }
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

    static func diceActionStep(creatureName: String, actionTitle: String, stepTitle: String, expression: DiceExpression) -> Self {
        RollDescription(
            expression: expression,
            title: AttributedString("\(stepTitle) - \(actionTitle) - \(creatureName)")
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
