//
//  ColumnNavigationViewState.swift
//  Construct
//
//  Created by Thomas Visser on 28/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture

struct ColumnNavigationViewState: Equatable {
    var sidebar: SidebarViewState = SidebarViewState()

    var diceCalculator = FloatingDiceRollerViewState(diceCalculator: DiceCalculatorState(
        displayOutcomeExternally: false,
        rollOnAppear: false,
        expression: .dice(count: 1, die: Die(sides: 20)),
        mode: .rollingExpression
    ))
}

enum ColumnNavigationViewAction: Equatable {
    case diceCalculator(FloatingDiceRollerViewAction)
    case sidebar(SidebarViewAction)
}

extension ColumnNavigationViewState {
    static let reducer: Reducer<Self, ColumnNavigationViewAction, Environment> = Reducer.combine(
        FloatingDiceRollerViewState.reducer.pullback(state: \.diceCalculator, action: /ColumnNavigationViewAction.diceCalculator),
        SidebarViewState.reducer.pullback(state: \.sidebar, action: /ColumnNavigationViewAction.sidebar),
        Reducer { state, action, env in
            switch action {
            case .sidebar(.onDiceRollerButtonTap):
                return Effect(value: .diceCalculator(.show))
                    .receive(on: env.mainQueue.animation())
                    .eraseToEffect()
            case .sidebar:
                if state.diceCalculator.canCollapse {
                    return Effect(value: .diceCalculator(.collapse))
                        .receive(on: env.mainQueue.animation())
                        .eraseToEffect()
                }
            default: break
            }
            return .none
        }
    )

    static let nullInstance = ColumnNavigationViewState()

}
