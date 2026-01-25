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

@Reducer
public struct DiceRollerFeature {

    public init() { }

    @ObservableState
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
        Scope(state: \.calculatorState, action: \.calculatorState) {
            DiceCalculator()
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

public extension DiceRollerFeature.State {
    static let nullInstance = DiceRollerFeature.State()
}
