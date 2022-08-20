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
public struct Async<Success, Failure> where Failure: Error {
    var identifier: AnyHashable
    public var isLoading: Bool
    public var result: Result<Success, Failure>?

    public init(identifier: AnyHashable = UUID(), isLoading: Bool = false, result: Result<Success, Failure>? = nil) {
        self.identifier = identifier
        self.isLoading = isLoading
        self.result = result
    }

    public var value: Success? {
        guard case .success(let value)? = result else { return nil }
        return value
    }

    public var error: Failure? {
        guard case .failure(let error)? = result else { return nil }
        return error
    }

    public static var initial: Async {
        Async()
    }

    public enum Action {
        case startLoading
        case didStartLoading
        case didFinishLoading(Result<Success, Failure>)
        case reset
    }

    public static func reducer<Environment>(_ fetch: @escaping (Environment) -> AnyPublisher<Success, Failure>) -> Reducer<Self, Action, Environment> {
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
    public static func ==(lhs: Async<Success, Failure>, rhs: Async<Success, Failure>) -> Bool {
        (lhs.identifier, lhs.isLoading, lhs.result?.value, lhs.result?.error == nil) ==
        (rhs.identifier, rhs.isLoading, rhs.result?.value, rhs.result?.error == nil)
    }
}

extension Async.Action: Equatable where Success: Equatable {
    public static func ==(lhs: Async<Success, Failure>.Action, rhs: Async<Success, Failure>.Action) -> Bool {
        switch (lhs, rhs) {
        case (.startLoading, .startLoading): return true
        case (.didStartLoading, .didStartLoading): return true
        case (.didFinishLoading(.success(let s1)), .didFinishLoading(.success(let s2))): return s1 == s2
        case (.didFinishLoading(.failure), .didFinishLoading(.failure)): return true
        case (.didFinishLoading, .didFinishLoading): return false // tv: saw this during a big refactor, fixme?
        case (.reset, .reset): return true

        // the following is so we get a warning when a new action is added
        case (.startLoading, _): return false
        case (.didStartLoading, _): return false
        case (.didFinishLoading, _): return false
        case (.reset, _): return false
        }
    }
}

public struct ResultSet<Input, Success, Failure> where Failure: Error {
    public var input: Input
    public var result: Async<Success, Failure>

    public var lastResult: LastResult?

    public init(input: Input) {
        self.input = input
        self.result = .initial
        self.lastResult = nil
    }

    public var value: Success? {
        result.value ?? lastResult?.value
    }

    public var error: Error? {
        result.error
    }

    public struct LastResult {
        public var input: Input
        public var value: Success
    }

    public enum Action<InputAction> {
        case input(InputAction, debounce: Bool)
        case result(Async<Success, Failure>.Action)
        case reset
        case reload

        // Key-path support
        var result: Async<Success, Failure>.Action? {
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

    public static func reducer<InputAction, Environment>(_ input: Reducer<Input, InputAction, Environment>, _ fetch: @escaping (Input) -> ((Environment) -> AnyPublisher<Success, Failure>)?) -> Reducer<Self, Action<InputAction>, Environment> {
        var asyncReducer: Reducer<Async<Success, Failure>, Async<Success, Failure>.Action, Environment>?
        return Reducer.combine(
            input.pullback(state: \.input, action: CasePath(embed: { .input($0, debounce: true) }, extract: { $0.input })),
            Reducer.init { state, action, env in
                switch action {
                case .input(_, let debounce):
                    if let fetch = fetch(state.input) {
                        if state.lastResult == nil && !debounce {
                            asyncReducer = Async<Success, Failure>.reducer(fetch)
                        } else {
                            asyncReducer = Async<Success, Failure>.reducer { env in
                                fetch(env).delaySubscription(for: 0.5, scheduler: RunLoop.main)
                            }
                        }
                        return Effect(value: .result(.startLoading))
                    } else {
                        return Effect(value: .reset)
                    }
                case .reset:
                    state.lastResult = nil
                    return Effect(value: .result(.reset))
                case .reload:
                    if let fetch = fetch(state.input) {
                        asyncReducer = Async<Success, Failure>.reducer(fetch)

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
