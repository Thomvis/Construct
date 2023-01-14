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

public enum MapAction<InputAction, ResultAction> {
    case input(InputAction)
    case result(ResultAction)
}

public extension MapState {
    
    static func reducer<InputAction, ResultAction, Environment>(
        inputReducer: Reducer<Input, InputAction, Environment>,
        initialResultStateForInput resultState: @escaping (Input) -> Result,
        initialResultActionForInput resultAction: @escaping (Input) -> ResultAction?,
        resultReducerForInput: @escaping (Input) -> Reducer<Result, ResultAction, Environment>
    ) -> Reducer<Self, MapAction<InputAction, ResultAction>, Environment> {
        var resultReducerCancellationId: UUID? = nil
        var resultReducer: Reducer<Result, ResultAction, Environment>? = nil
        return Reducer.combine(
            inputReducer.pullback(state: \.input, action: /MapAction.input),
            Reducer { state, action, env in
                switch action {
                case .input: break // handled above
                case .result(let a):
                    assert(resultReducer != nil)
                    if let reducer = resultReducer {
                        return reducer(&state.result, a, env).map(MapAction.result)
                    }
                }
                return .none
            }
        )
        .onChange(of: \.input) { input, state, action, env in
            let cancellationId = UUID()

            state.result = resultState(input)
            resultReducer = resultReducerForInput(input)
                                .cancellable(id: cancellationId)

            let previousCancellationId = resultReducerCancellationId
            resultReducerCancellationId = cancellationId

            return .merge([
                previousCancellationId.map(Effect.cancel),
                resultAction(input).map { Effect(value: .result($0)) }
            ].compactMap { $0 })
        }
    }
}

extension MapState: Equatable where Result: Equatable { }

extension MapAction: Equatable where InputAction: Equatable, ResultAction: Equatable { }
