//
//  DiceRollerViewState.swift
//  Construct
//
//  Created by Thomas Visser on 31/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct DiceRollerViewState: Equatable {
    var calculatorState: DiceCalculatorState
    var diceLog: [DiceLogEntry]
    var showOutcome: Bool

    init() {
        self.calculatorState = DiceCalculatorState(
            displayOutcomeExternally: true,
            rollOnAppear: false,
            expression: .number(0),
            mode: .editingExpression
        )
        self.diceLog = []
        self.showOutcome = false
    }
}

enum DiceRollerViewAction: Equatable {
    case calculatorState(DiceCalculatorAction)
    case hideOutcome
    case onProcessRollForDiceLog(RolledDiceExpression, RollDescription)

    var calculatorState: DiceCalculatorAction? {
        guard case .calculatorState(let a) = self else { return nil }
        return a
    }
}

extension DiceRollerViewState {
    static let reducer: Reducer<Self, DiceRollerViewAction, Environment> = Reducer.combine(
        Reducer { state, action, _ in
            switch action {
            case .calculatorState(.onExpressionEditRollButtonTap):
                state.showOutcome = true
            case .calculatorState: break
            case .hideOutcome:
                state.showOutcome = false
            case .onProcessRollForDiceLog(let result, let roll):
                let result: DiceLogEntry.Result = .init(
                    id: UUID().tagged(),
                    type: .normal,
                    first: result,
                    second: nil
                )

                if state.diceLog.last?.roll == roll {
                    state.diceLog[state.diceLog.endIndex-1].results.append(result)
                } else {
                    state.diceLog.append(DiceLogEntry(
                        id: UUID().tagged(),
                        roll: roll,
                        results: [
                            result
                        ]
                    ))
                }
            }
            return .none
        },
        DiceCalculatorState.reducer.pullback(state: \.calculatorState, action: /DiceRollerViewAction.calculatorState, environment: { $0 })
//            .onChange(of: { $0.calculatorState.intermediaryResult == nil ? $0.calculatorState.result : nil }) { result, state, action, env in
//                if let result = result {
//                    let roll: DiceLogEntry.Roll = .custom(state.calculatorState.expression)
//                    let result: DiceLogEntry.Result = .init(
//                        id: UUID().tagged(),
//                        type: .normal,
//                        first: result,
//                        second: nil
//                    )
//
//                    if state.diceLog.last?.roll == roll {
//                        state.diceLog[state.diceLog.endIndex-1].results.append(result)
//                    } else {
//                        state.diceLog.append(DiceLogEntry(
//                            id: UUID().tagged(),
//                            roll: roll,
//                            results: [
//                                result
//                            ]
//                        ))
//                    }
//                }
//
//                return .none
//            }
    )

    static let nullInstance = DiceRollerViewState()
}
