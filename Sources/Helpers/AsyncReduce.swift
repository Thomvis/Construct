//
//  AsyncReduce.swift
//  
//
//  Created by Thomas Visser on 12/02/2023.
//

import Foundation
import ComposableArchitecture

public struct AsyncReduceState<Result, Failure> where Failure: Error {
    private let id = UUID()
    public var value: Result
    public var state: State = .initial

    public init(value: Result) {
        self.value = value
    }

    public enum State {
        case initial
        case reducing
        case failed(Failure)
        case finished
    }
}

public enum AsyncReduceAction<Result, Failure, Element> where Failure: Error {
    case start(Result)
    case onElement(Element)
    case onError(Failure)
    case didFinish
    case stop
}

public extension AsyncReduceState {
    static func reducer<S: AsyncSequence, Environment>(
        _ sequence: @escaping (Environment) throws -> S,
        reduce: @escaping (inout Result, S.Element) -> Void,
        mapError: @escaping (Error) -> Failure
    ) -> AnyReducer<Self, AsyncReduceAction<Result, Failure, S.Element>, Environment> {
        return AnyReducer { state, action, env in
            switch action {
            case .start(let res):
                state.value = res
                state.state = .reducing
                return EffectTask.run { send in
                    do {
                        for try await elem in try sequence(env) {
                            await send(.onElement(elem))
                            try Task.checkCancellation()
                        }
                        try Task.checkCancellation()
                        await send(.didFinish)
                    } catch {
                        await send(.onError(mapError(error)))
                    }
                }
                .cancellable(id: state.id)
            case .onElement(let elem):
                reduce(&state.value, elem)
            case .onError(let error):
                state.state = .failed(error)
            case .didFinish:
                state.state = .finished
            case .stop:
                if case .reducing = state.state {
                    state.state = .failed(mapError(CancellationError()))
                }
                return .cancel(id: state.id)
            }
            return .none
        }
    }
}

extension AsyncReduceState: Equatable where Result: Equatable, Failure: Equatable { }

extension AsyncReduceState.State: Equatable where Failure: Equatable { }

extension AsyncReduceAction: Equatable where Result: Equatable, Failure: Equatable, Element: Equatable { }

extension AsyncReduceState {
    public var error: Failure? {
        if case .failed(let error) = state {
            return error
        }
        return nil
    }

    public var isReducing: Bool {
        if case .reducing = state {
            return true
        }
        return false
    }
}
