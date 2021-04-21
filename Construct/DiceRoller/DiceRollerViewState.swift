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
    var showOutcome: Bool

    init() {
        self.calculatorState = DiceCalculatorState(
            displayOutcomeExternally: true,
            rollOnAppear: false,
            expression: .number(0),
            mode: .editingExpression
        )
        self.showOutcome = false
    }
}

enum DiceRollerViewAction: Equatable {
    case calculatorState(DiceCalculatorAction)
    case hideOutcome

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
            }
            return .none
        },
        DiceCalculatorState.reducer.pullback(state: \.calculatorState, action: /DiceRollerViewAction.calculatorState, environment: { $0 })
    )

    static let nullInstance = DiceRollerViewState()
}
