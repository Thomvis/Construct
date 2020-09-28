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
    var diceCalculator: DiceCalculatorState = DiceCalculatorState(
        displayOutcomeExternally: false,
        rollOnAppear: false,
        expression: .number(0),
        mode: .editingExpression
    )
}

enum ColumnNavigationViewAction: Equatable {
    case diceCalculator(DiceCalculatorAction)
}

extension ColumnNavigationViewState {
    static let reducer: Reducer<Self, ColumnNavigationViewAction, Environment> = Reducer.combine(
        DiceCalculatorState.reducer.pullback(state: \.diceCalculator, action: /ColumnNavigationViewAction.diceCalculator)
    )
}
