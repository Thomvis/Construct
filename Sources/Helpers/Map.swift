//
//  Map.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import ComposableArchitecture

public struct MapState<Input, Result> where Input: Equatable {
    public var input: Input
    public var result: Result

    public init(input: Input, result: Result) {
        self.input = input
        self.result = result
    }
}

public enum MapAction<Input, InputAction, Result, ResultAction> {
    case input(InputAction)
    case result(ResultAction)
    case set(Input, Result?)
}

public extension MapState {
    
    static func reducer<InputAction, ResultAction, Environment>(
        inputReducer: AnyReducer<Input, InputAction, Environment>,
        initialResultStateForInput resultState: @escaping (Input) -> Result,
        initialResultActionForInput resultAction: @escaping (Input) -> ResultAction?,
        resultReducerForInput: @escaping (Input) -> AnyReducer<Result, ResultAction, Environment>
    ) -> AnyReducer<Self, MapAction<Input, InputAction, Result, ResultAction>, Environment> {
        var resultReducerCancellationId: UUID? = nil
        var resultReducer: AnyReducer<Result, ResultAction, Environment>? = nil

        func updateReducer(state: inout Self) -> EffectTask<MapAction<Input, InputAction, Result, ResultAction>> {
            let cancellationId = UUID()

            state.result = resultState(state.input)
            resultReducer = resultReducerForInput(state.input)
                                .cancellable(id: cancellationId)

            let previousCancellationId = resultReducerCancellationId
            resultReducerCancellationId = cancellationId            

            return .concatenate([
                previousCancellationId.map { .cancel(id: $0) },
                resultAction(state.input).map { .send(.result($0)) }
            ].compactMap { $0 })
        }

        return AnyReducer.combine(
            inputReducer.pullback(state: \.input, action: /MapAction.input)
                .onChange(of: \.input) { input, state, action, env in
                    return updateReducer(state: &state)
                },
            AnyReducer { state, action, env in
                switch action {
                case .input: break // handled above
                case .result(let a):
                    if resultReducer == nil {
                        _ = updateReducer(state: &state)
                    }

                    if let reducer = resultReducer {
                        return reducer(&state.result, a, env).map(MapAction.result)
                    }
                case .set(let input, nil):
                    state.input = input
                    return updateReducer(state: &state)
                case .set(let input, let result?):
                    state.input = input
                    state.result = result

                    // like updateReducer but without setting the result & emitting the initial action
                    let cancellationId = UUID()

                    resultReducer = resultReducerForInput(state.input)
                                        .cancellable(id: cancellationId)

                    let previousCancellationId = resultReducerCancellationId
                    resultReducerCancellationId = cancellationId

                    return .concatenate([
                        previousCancellationId.map { .cancel(id: $0) },
                    ].compactMap { $0 })
                }
                return .none
            }
        )
    }
}

extension MapState: Equatable where Result: Equatable { }

extension MapAction: Equatable where Input: Equatable, InputAction: Equatable, Result: Equatable, ResultAction: Equatable { }
