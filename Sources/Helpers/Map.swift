//
//  Map.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import ComposableArchitecture

public struct Map<Input, Result>: Reducer
where Input: Reducer, Result: Reducer, Input.State: Equatable {
    let inputReducer: Input
    let initialResultStateForInput: (Input.State) -> Result.State
    let initialResultActionForInput: (Input.State) -> Result.Action?
    let resultReducerForInput: (Input.State) -> Result

    public init(
        inputReducer: Input,
        initialResultStateForInput: @escaping (Input.State) -> Result.State,
        initialResultActionForInput: @escaping (Input.State) -> Result.Action?,
        resultReducerForInput: @escaping (Input.State) -> Result
    ) {
        self.inputReducer = inputReducer
        self.initialResultStateForInput = initialResultStateForInput
        self.initialResultActionForInput = initialResultActionForInput
        self.resultReducerForInput = resultReducerForInput
    }

    public struct State {
        public var input: Input.State
        public var result: Result.State
        var cancellationId: UUID?

        public init(input: Input.State, result: Result.State) {
            self.input = input
            self.result = result
            self.cancellationId = nil
        }
    }

    public enum Action {
        case input(Input.Action)
        case result(Result.Action)
        case set(Input.State, Result.State?)
    }

    @Dependency(\.uuid) var uuid

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        func updateReducer() -> Effect<Action> {
            let previousCancellationId = state.cancellationId
            let cancellationId = uuid()

            state.result = initialResultStateForInput(state.input)
            state.cancellationId = cancellationId

            let resultAction = initialResultActionForInput(state.input)

            return .merge(
                previousCancellationId.map { .cancel(id: $0) } ?? .none,
                resultAction.map { .send(.result($0)) } ?? .none
            )
        }

        switch action {
        case .input(let inputAction):
            let previousInput = state.input
            
            let inputEffect: Effect<Action> = inputReducer.reduce(into: &state.input, action: inputAction)
                .map { Action.input($0) }

            if previousInput != state.input {
                return .merge(
                    inputEffect,
                    updateReducer()
                )
            } else {
                return inputEffect
            }

        case .result(let resultAction):
            if state.cancellationId == nil {
                _ = updateReducer()
            }

            guard let cancellationId = state.cancellationId else {
                return .none
            }

            let resultReducer = resultReducerForInput(state.input)
            return resultReducer.reduce(into: &state.result, action: resultAction)
                .map { Action.result($0) }
                .cancellable(id: cancellationId)

        case .set(let input, nil):
            state.input = input
            return updateReducer()

        case .set(let input, let result?):
            state.input = input
            state.result = result

            let cancellationId = UUID()
            let previousCancellationId = state.cancellationId
            state.cancellationId = cancellationId

            return previousCancellationId.map { .cancel(id: $0) } ?? .none
        }
    }
}

extension Map.State: Equatable where Result.State: Equatable { }

extension Map.Action: Equatable where Input.Action: Equatable, Result.State: Equatable, Result.Action: Equatable { }
