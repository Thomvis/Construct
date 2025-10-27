//
//  DiceRollerViewState.swift
//  Construct
//
//  Created by Thomas Visser on 31/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Dice
import Helpers

public struct DiceRollerViewState: Equatable {
    public var calculatorState: DiceCalculator.State
    public var diceLog: DiceLog
    public var showOutcome: Bool

    public init() {
        self.calculatorState = DiceCalculator.State(
            displayOutcomeExternally: true,
            rollOnAppear: false,
            expression: .number(0),
            mode: .editingExpression
        )
        self.diceLog = DiceLog()
        self.showOutcome = false
    }
}

public enum DiceRollerViewAction: Equatable {
    case calculatorState(DiceCalculator.Action)
    case hideOutcome
    case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
    case onClearDiceLog

    var calculatorState: DiceCalculator.Action? {
        guard case .calculatorState(let a) = self else { return nil }
        return a
    }
}

public protocol EnvironmentWithDiceLog {
    var diceLog: DiceLogPublisher { get }
}

public typealias DiceRollerEnvironment = EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog

public struct StandaloneDiceRollerEnvironment: DiceRollerEnvironment {
    public let mainQueue: AnySchedulerOf<DispatchQueue>
    public let diceLog: DiceLogPublisher
    public let modifierFormatter: NumberFormatter

    public init(mainQueue: AnySchedulerOf<DispatchQueue>, diceLog: DiceLogPublisher, modifierFormatter: NumberFormatter) {
        self.mainQueue = mainQueue
        self.diceLog = diceLog
        self.modifierFormatter = modifierFormatter
    }
}

public extension DiceRollerViewState {
    static let reducer: AnyReducer<Self, DiceRollerViewAction, DiceRollerEnvironment> = AnyReducer.combine(
        AnyReducer { state, action, _ in
            switch action {
            case .calculatorState(.onExpressionEditRollButtonTap):
                state.showOutcome = true
            case .calculatorState: break
            case .hideOutcome:
                state.showOutcome = false
            case .onProcessRollForDiceLog(let result, let roll):
                state.diceLog.receive(result, for: roll)
            case .onClearDiceLog:
                state.diceLog.clear()
        }
        return .none
    },
        AnyReducer { env in
            DiceCalculator(environment: env)
        }
        .pullback(
            state: \.calculatorState,
            action: /DiceRollerViewAction.calculatorState,
            environment: { $0 }
        )
    )

    static let nullInstance = DiceRollerViewState()
}
