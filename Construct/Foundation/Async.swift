//
//  Async.swift
//  Construct
//
//  Created by Thomas Visser on 24/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import ComposableArchitecture

// Storage of an async result
struct Async<Success, Failure, Environment> where Failure: Error {
    var identifier: AnyHashable = UUID()
    var isLoading: Bool = false
    var result: Result<Success, Failure>?

    var value: Success? {
        guard case .success(let value)? = result else { return nil }
        return value
    }

    var error: Failure? {
        guard case .failure(let error)? = result else { return nil }
        return error
    }

    static var initial: Async {
        Async()
    }

    enum Action {
        case startLoading
        case didStartLoading
        case didFinishLoading(Result<Success, Failure>)
        case reset
    }

    static func reducer(_ fetch: @escaping (Environment) -> AnyPublisher<Success, Failure>) -> Reducer<Self, Action, Environment> {
        return Reducer { state, action, environment in
            switch action {
            case .startLoading:
                return fetch(environment)
                    .catchToEffect()
                    .map { Action.didFinishLoading($0) }
                    .prepend(Action.didStartLoading)
                    .eraseToEffect()
                    .cancellable(id: state.identifier, cancelInFlight: true)
            case .didStartLoading:
                state.isLoading = true
            case .didFinishLoading(let result):
                state.result = result
                state.isLoading = false
            case .reset:
                state.result = nil
                state.isLoading = false
                return .cancel(id: state.identifier)
            }
            return .none
        }
    }
}

extension Async: Equatable where Success: Equatable {
    static func ==(lhs: Async<Success, Failure, Environment>, rhs: Async<Success, Failure, Environment>) -> Bool {
        (lhs.identifier, lhs.isLoading, lhs.result?.value, lhs.result?.error == nil) ==
        (rhs.identifier, rhs.isLoading, rhs.result?.value, rhs.result?.error == nil)
    }
}

extension Async.Action: Equatable where Success: Equatable {
    static func ==(lhs: Async<Success, Failure, Environment>.Action, rhs: Async<Success, Failure, Environment>.Action) -> Bool {
        switch (lhs, rhs) {
        case (.startLoading, .startLoading): return true
        case (.didStartLoading, .didStartLoading): return true
        case (.didFinishLoading(.success(let s1)), .didFinishLoading(.success(let s2))): return s1 == s2
        case (.didFinishLoading(.failure), .didFinishLoading(.failure)): return true
        case (.didFinishLoading, .didFinishLoading): return false
        case (.reset, .reset): return true

        // the following is so we get a warning when a new action is added
        case (.startLoading, _): return false
        case (.didStartLoading, _): return false
        case (.didFinishLoading, _): return false
        case (.reset, _): return false
        }
    }
}

struct ResultSet<Input, Success, Failure> where Failure: Error {
    var input: Input
    var result: Async<Success, Failure, Environment>

    var lastResult: LastResult?

    init(input: Input) {
        self.input = input
        self.result = .initial
        self.lastResult = nil
    }

    var value: Success? {
        result.value ?? lastResult?.value
    }

    var error: Error? {
        result.error
    }

    struct LastResult {
        var input: Input
        var value: Success
    }

    enum Action<InputAction> {
        case input(InputAction, debounce: Bool)
        case result(Async<Success, Failure, Environment>.Action)
        case reset
        case reload

        // Key-path support
        var result: Async<Success, Failure, Environment>.Action? {
            get {
                guard case .result(let a) = self else { return nil }
                return a
            }
            set {
                guard case .result = self, let value = newValue else { return }
                self = .result(value)
            }
        }

        var input: InputAction? {
            guard case .input(let a, _) = self else { return nil }
            return a
        }
    }

    static func reducer<InputAction>(_ input: Reducer<Input, InputAction, Environment>, _ fetch: @escaping (Input) -> ((Environment) -> AnyPublisher<Success, Failure>)?) -> Reducer<Self, Action<InputAction>, Environment> {
        var asyncReducer: Reducer<Async<Success, Failure, Environment>, Async<Success, Failure, Environment>.Action, Environment>?
        return Reducer.combine(
            input.pullback(state: \.input, action: CasePath(embed: { .input($0, debounce: true) }, extract: { $0.input })),
            Reducer.init { state, action, env in
                switch action {
                case .input(_, let debounce):
                    if let fetch = fetch(state.input) {
                        if state.lastResult == nil && !debounce {
                            asyncReducer = Async<Success, Failure, Environment>.reducer(fetch)
                        } else {
                            asyncReducer = Async<Success, Failure, Environment>.reducer { env in
                                fetch(env).delaySubscription(for: 0.5, scheduler: RunLoop.main)
                            }
                        }
                        return Effect(value: .result(.startLoading))
                    } else {
                        return Effect(value: .reset)
                    }
                case .reset:
                    state.lastResult = nil
                    if asyncReducer != nil {
                        return Effect(value: .result(.reset))
                    }
                    return Effect.none
                case .reload:
                    if let fetch = fetch(state.input) {
                        asyncReducer = Async<Success, Failure, Environment>.reducer(fetch)

                        return Effect(value: .result(.startLoading))
                    } else {
                        return Effect(value: .reset)
                    }
                case .result(let a): // forward all result actions
                    if case .result(.didFinishLoading(.success(let value))) = action {
                        state.lastResult = LastResult(input: state.input, value: value)
                    }

                    assert(asyncReducer != nil)
                    return asyncReducer?(&state.result, a, env).map { action in
                        .result(action)
                    } ?? .none
                }
            }
        )
    }
}

extension ResultSet.LastResult: Equatable where Input: Equatable, Success: Equatable { }

extension ResultSet: Equatable where Input: Equatable, Success: Equatable { }

extension ResultSet.Action: Equatable where InputAction: Equatable, Success: Equatable { }
