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
        fileprivate let id: UUID
        public var input: Input.State
        public var result: Result.State

        public init(input: Input.State, result: Result.State) {
            @Dependency(\.uuid) var uuid
            self.id = uuid()
            self.input = input
            self.result = result
        }
    }

    public enum Action {
        case input(Input.Action)
        case result(Result.Action)
        case set(Input.State, Result.State?)
    }

    @Dependency(\.uuid) var uuid

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        func invokeResultReducer(action: Result.Action) -> Effect<Action> {
            let resultReducer = resultReducerForInput(state.input)
            print("TV map[\(state.id)] .result(\(String(describing: action).prefix(100)))")
            return resultReducer.reduce(into: &state.result, action: action)
                .cancellable(id: state.id)
                .map { Action.result($0) }
        }

        func onInputDidChange() -> Effect<Action> {
            state.result = initialResultStateForInput(state.input)

            let resultAction = initialResultActionForInput(state.input)

            print("TV map[\(state.id)] cancelling")
            return .concatenate(
                .cancel(id: state.id), // cancel effects from the result reducer
                resultAction.map { invokeResultReducer(action: $0) } ?? .none,
                .run { _ in
                    do {
                        do {
                            print("TV night night")
                            try await Task.sleep(for: .seconds(1))
                            print("TV good morning")
                        } catch is CancellationError {
                            print("TV sleep cancelled inner")
                        }
                    } catch is CancellationError {
                        print("TV sleep cancelled")
                    }
                }
                .cancellable(id: state.id)
            )
        }

        switch action {
        case .input(let inputAction):
            let previousInput = state.input
            
            let inputEffect: Effect<Action> = inputReducer.reduce(into: &state.input, action: inputAction)
                .map { Action.input($0) }

            if previousInput != state.input {
                print("TV map input changed")
                return .concatenate(
                    inputEffect,
                    onInputDidChange()
                )
            } else {
                return inputEffect
            }

        case .result(let resultAction):
            let resultReducer = resultReducerForInput(state.input)
            print("TV map[\(state.id)] .result(\(String(describing: resultAction).prefix(100)))")
            return resultReducer.reduce(into: &state.result, action: resultAction)
                .cancellable(id: state.id)
                .map { Action.result($0) }
//                .cancellable(id: state.id)  // make all effects from the result reducer cancellable
                                            // does not work as well as I'd hoped (see tests)

        case .set(let input, nil):
            state.input = input
            return onInputDidChange()

        case .set(let input, let result?):
            state.input = input
            state.result = result

            print("TV map[\(state.id)] .set")
            return .cancel(id: state.id)
        }
    }
}

extension Map.State: Equatable where Result.State: Equatable { }

extension Map.Action: Equatable where Input.Action: Equatable, Result.State: Equatable, Result.Action: Equatable { }
