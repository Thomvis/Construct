//
//  DiceActionViewState.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import CasePaths

struct DiceActionViewState: Hashable {
    var action: DiceAction
}

enum DiceActionViewAction: Hashable {
    case rollAll
    case stepAction(UUID, DiceActionStepAction)
}

enum DiceActionStepAction: Hashable {
    case value(ValueAction)
    case rollDetails(DiceCalculatorAction)

    enum ValueAction: Hashable {
        case roll(RollAction)

        enum RollAction: Hashable {
            case roll
            case type(DiceAction.Step.Value.RollValue.RollType)
            case first(AnimatedRollAction)
            case second(AnimatedRollAction)
            case details(DiceAction.Step.Value.RollValue.Details?)
        }
    }
}

// Reducers

extension DiceActionViewState {
    static var reducer: Reducer<Self, DiceActionViewAction, Environment> = Reducer.combine(
        DiceAction.Step.reducer.forEach(state: \.action.steps, action: /DiceActionViewAction.stepAction, environment: { $0 }),
        Reducer { state, action, env in
            switch action {
            case .rollAll:
                return state.action.steps.compactMap { step in
                    if case .roll = step.value {
                        return DiceActionViewAction.stepAction(step.id, .value(.roll(.roll)))
                    }
                    return nil
                }.publisher.eraseToEffect()
            case .stepAction(let id, .value(.roll(.details(_?)))):
                return state.action.steps.filter { $0.id != id && $0.rollDetails != nil }.map {
                    .stepAction($0.id, .value(.roll(.details(nil))))
                }.publisher.eraseToEffect()
            case .stepAction: break
            }
            return .none
        }
    )
}

extension DiceAction.Step {
    static var reducer: Reducer<Self, DiceActionStepAction, Environment> = Reducer.combine(
        Reducer.combine(
            AnimatedRollState.reducer
                .pullback(state: \DiceAction.Step.Value.RollValue.first, action: /DiceActionStepAction.ValueAction.RollAction.first),
            AnimatedRollState.reducer.optional()
                .pullback(state: \DiceAction.Step.Value.RollValue.second, action: /DiceActionStepAction.ValueAction.RollAction.second)
        )
        .optional()
        .pullback(state: \DiceAction.Step.rollValue, action: /DiceActionStepAction.value..DiceActionStepAction.ValueAction.roll),
        DiceCalculatorState.reducer.optional().pullback(state: \.rollDetails, action: /DiceActionStepAction.rollDetails),
        Reducer { state, action, env in
            let cp: CasePath<DiceActionStepAction, DiceActionStepAction.ValueAction> = /DiceActionStepAction.value
            switch action {
            case .value(.roll(.roll)):
                guard let rollValue = state.rollValue else { return .none }
                var actions: [DiceActionStepAction] = [
                    .value(.roll(.first(.roll(rollValue.expression))))
                ]

                if rollValue.type != .normal {
                    actions.append(.value(.roll(.second(.roll(rollValue.expression)))))
                }
                
                return actions.publisher.eraseToEffect()
            case .value(.roll(.type(let t))):
                guard let rollValue = state.rollValue else { return .none }

                state.rollValue?.type = t
                if t != .normal {
                    if state.rollValue?.second == nil {
                        state.rollValue?.second = AnimatedRollState(expression: rollValue.expression, result: nil, intermediaryResult: nil)
                        if rollValue.first.result != nil {
                            return Effect(value: .value(.roll(.second(.roll(rollValue.expression)))))
                        }
                    }
                } else {
                    state.rollValue?.second = nil
                }
            case .value(.roll(.details(let d))):
                state.rollValue?.details = d
            case .value(.roll): break
            case .rollDetails: break // handled above
            }
            return .none
        }
    )
}

extension DiceActionViewState {
    static let nullInstance = DiceActionViewState(action: DiceAction(title: "", subtitle: "", steps: []))
}
