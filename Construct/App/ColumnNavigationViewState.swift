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

    var diceCalculator: DiceCalculatorState = DiceCalculatorState(
        displayOutcomeExternally: false,
        rollOnAppear: false,
        expression: .number(0),
        mode: .editingExpression
    )
}

enum ColumnNavigationViewAction: Equatable {
    case diceCalculator(DiceCalculatorAction)
    case sidebar(SidebarViewAction)
}

extension ColumnNavigationViewState {
    static let reducer: Reducer<Self, ColumnNavigationViewAction, Environment> = Reducer.combine(
        DiceCalculatorState.reducer.pullback(state: \.diceCalculator, action: /ColumnNavigationViewAction.diceCalculator),
        SidebarViewState.reducer.pullback(state: \.sidebar, action: /ColumnNavigationViewAction.sidebar)
    )
}
