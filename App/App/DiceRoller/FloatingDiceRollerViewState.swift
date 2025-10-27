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
    var diceCalculator: DiceCalculator.State
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
    case diceCalculator(DiceCalculator.Action)
    case hide
    case content(FloatingDiceRollerViewState.Content)
    case show
    case collapse
    case expand

    case onProcessRollForDiceLog(DiceLogEntry.Result, RollDescription)
    case onClearDiceLog
}

extension FloatingDiceRollerViewState {
    static let reducer: AnyReducer<Self, FloatingDiceRollerViewAction, Environment> = AnyReducer.combine(
        AnyReducer { env in
            DiceCalculator(environment: env)
        }
        .pullback(
            state: \.diceCalculator,
            action: /FloatingDiceRollerViewAction.diceCalculator,
            environment: { $0 }
        ),
        AnyReducer { state, action, env in
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
            case .onClearDiceLog:
                state.diceLog.clear()
            }
            return .none
        }
    )
}
