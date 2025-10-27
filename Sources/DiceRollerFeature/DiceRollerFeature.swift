//
//  DiceRollerFeature.swift
//  Construct
//
//  Created by Thomas Visser on 31/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Dice
import Helpers

public struct DiceRollerFeature: Reducer {

    let environment: DiceRollerEnvironment

    public init(environment: DiceRollerEnvironment) {
        self.environment = environment
    }

    public struct State: Equatable {
        public var calculatorState: DiceCalculator.State
        public var diceLog: DiceLog
        public var showOutcome: Bool

        public init(
            calculatorState: DiceCalculator.State = DiceCalculator.State(
                displayOutcomeExternally: true,
                rollOnAppear: false,
                expression: .number(0),
                mode: .editingExpression
            ),
            diceLog: DiceLog = DiceLog(),
            showOutcome: Bool = false
        ) {
            self.calculatorState = calculatorState
            self.diceLog = diceLog
            self.showOutcome = showOutcome
        }
    }

    public enum Action: Equatable {
        case calculatorState(DiceCalculator.Action)
        case hideOutcome
        case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
        case onClearDiceLog
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.calculatorState, action: /Action.calculatorState) {
            DiceCalculator(environment: environment)
        }

        Reduce { state, action in
            switch action {
            case .calculatorState(.onExpressionEditRollButtonTap):
                state.showOutcome = true
            case .calculatorState:
                break
            case .hideOutcome:
                state.showOutcome = false
            case .onProcessRollForDiceLog(let result, let roll):
                state.diceLog.receive(result, for: roll)
            case .onClearDiceLog:
                state.diceLog.clear()
            }
            return .none
        }
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

public extension DiceRollerFeature.State {
    static let nullInstance = DiceRollerFeature.State()
}
