//
//  FloatingDiceRollerViewState.swift
//  Construct
//
//  Created by Thomas Visser on 11/03/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct FloatingDiceRollerViewState: Equatable {
    var hidden: Bool = false
    var diceCalculator: DiceCalculatorState

    var canCollapse: Bool {
        diceCalculator.mode != .rollingExpression
    }
}

enum FloatingDiceRollerViewAction: Equatable {
    case diceCalculator(DiceCalculatorAction)
    case hide
    case show
    case collapse
    case expand
}

extension FloatingDiceRollerViewState {
    static let reducer: Reducer<Self, FloatingDiceRollerViewAction, Environment> = Reducer.combine(
        DiceCalculatorState.reducer.pullback(state: \.diceCalculator, action: /FloatingDiceRollerViewAction.diceCalculator),
        Reducer { state, action, env in
            switch action {
            case .diceCalculator: break // handled above
            case .hide:
                state.hidden = true
            case .show:
                state.hidden = false
                state.diceCalculator.mode = .editingExpression
            case .collapse:
                state.diceCalculator.mode = .rollingExpression
            case .expand:
                state.diceCalculator.mode = .editingExpression
            }
            return .none
        }
    )
}
