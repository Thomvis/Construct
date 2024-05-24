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
import Dice
import Helpers

public struct DiceLogPublisher {
    private let subject: PassthroughSubject<(DiceLogEntry.Result, RollDescription), Never> = .init()

    public init() {
        
    }

    public var rolls: AnyPublisher<(DiceLogEntry.Result, RollDescription), Never> {
        subject.eraseToAnyPublisher()
    }

    public func didRoll(_ expression: RolledDiceExpression, roll: RollDescription) {
        didRoll(DiceLogEntry.Result(id: UUID().tagged(), type: .normal, first: expression, second: nil), roll: roll)
    }

    public func didRoll(_ result: DiceLogEntry.Result, roll: RollDescription) {
        subject.send((result, roll))
    }
}

public struct DiceLog: Hashable {
    public var entries: [DiceLogEntry] = []

    public init() {

    }

    public mutating func receive(_ result: DiceLogEntry.Result, for roll: RollDescription) {
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

    public mutating func clear() {
        entries = []
    }
}

public struct RollDescription: Hashable {
    public var expression: DiceExpression
    public var title: AttributedString

    public init(expression: DiceExpression, title: AttributedString) {
        self.expression = expression
        self.title = title
    }

    public static func custom(_ expression: DiceExpression) -> Self {
        RollDescription(
            expression: expression,
            title: AttributedString(expression.description)
        )
    }

    public static func diceActionStep(creatureName: String, actionTitle: String, stepTitle: String, expression: DiceExpression) -> Self {
        RollDescription(
            expression: expression,
            title: AttributedString("\(stepTitle) - \(actionTitle) - \(creatureName)")
        )
    }
}

public struct DiceLogEntry: Hashable {
    public let id: Tagged<DiceLogEntry, UUID>
    public let roll: RollDescription
    public var results: [Result]

    public struct Result: Hashable {
        public let id: Tagged<Result, UUID>
        public let type: ResultType

        public let first: RolledDiceExpression
        public let second: RolledDiceExpression?

        public init(id: Tagged<Result, UUID> = UUID().tagged(), type: ResultType, first: RolledDiceExpression, second: RolledDiceExpression?) {
            self.id = id
            self.type = type
            self.first = first
            self.second = second
        }

        public var effectiveResult: RolledDiceExpression {
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

        public enum ResultType: Hashable {
            case normal
            case disadvantage
            case advantage
        }
    }
}
