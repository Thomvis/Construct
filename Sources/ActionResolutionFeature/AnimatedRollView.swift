//
//  AnimatedRollView.swift
//  Construct
//
//  Created by Thomas Visser on 06/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Dice

struct AnimatedRollView<Content>: View where Content: View {
    @Binding var roll: AnimatedRollState
    let content: (RolledDiceExpression?, Bool) -> Content

    var body: some View {
        content(roll.effectiveResult, roll.isFinal)
    }
}

struct AnimatedRollState: Hashable {
    var expression: DiceExpression?
    var result: RolledDiceExpression?

    var intermediaryResult: RolledDiceExpression?

    var effectiveResult: RolledDiceExpression? {
        intermediaryResult ?? result
    }

    var isFinal: Bool {
        result != nil && intermediaryResult == nil
    }

    static var reducer: Reducer<Self, AnimatedRollAction, ActionResolutionEnvironment> = Reducer { state, action, env in
        switch action {
        case .roll(let expr):
            state.expression = expr
            state.result = expr.roll
            return Effect(value: .rollIntermediary(expr, 5))
        case .rollIntermediary(let expr, let remaining):
            guard expr == state.expression && remaining > 0 else {
                state.intermediaryResult = nil
                return .none
            }

            state.intermediaryResult = expr.roll

            return Effect(value: .rollIntermediary(expr, remaining-1))
                .delay(for: 0.08, scheduler: env.mainQueue.animation())
                .eraseToEffect()
        }
    }
}

public enum AnimatedRollAction: Hashable {
    case roll(DiceExpression)
    case rollIntermediary(DiceExpression, Int)
}
