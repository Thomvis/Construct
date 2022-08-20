//
//  FloatingDiceRollerViewState.swift
//  Construct
//
//  Created by Thomas Visser on 11/03/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import DiceRollerFeature

struct FloatingDiceRollerViewState: Equatable {
    var hidden: Bool = false
    var content: Content = .calculator
    var diceCalculator: DiceCalculatorState
    var diceLog = DiceLog()

    var canCollapse: Bool {
        diceCalculator.mode != .rollingExpression
    }

    enum Content: Equatable {
        case calculator
        case log
    }
}

enum FloatingDiceRollerViewAction: Equatable {
    case diceCalculator(DiceCalculatorAction)
    case hide
    case content(FloatingDiceRollerViewState.Content)
    case show
    case collapse
    case expand

    case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
}

extension FloatingDiceRollerViewState {
    static let reducer: Reducer<Self, FloatingDiceRollerViewAction, Environment> = Reducer.combine(
        DiceCalculatorState.reducer.pullback(state: \.diceCalculator, action: /FloatingDiceRollerViewAction.diceCalculator, environment: \.diceRollerEnvironment),
        Reducer { state, action, env in
            switch action {
            case .diceCalculator: break // handled above
            case .hide:
                state.hidden = true
            case .content(let c):
                state.content = c
            case .show:
                state.hidden = false
                state.diceCalculator.mode = .editingExpression
            case .collapse:
                state.diceCalculator.mode = .rollingExpression
            case .expand:
                state.diceCalculator.mode = .editingExpression
            case .onProcessRollForDiceLog(let result, let roll):
                state.diceLog.receive(result, for: roll)
            }
            return .none
        }
    )
}
