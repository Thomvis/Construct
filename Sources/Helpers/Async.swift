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
public struct Async<Success, Failure> where Failure: Swift.Error {
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

    public static func reducer<Environment>(_ fetch: @escaping (Environment) -> AnyPublisher<Success, Failure>) -> AnyReducer<Self, Action, Environment> {
        return AnyReducer { state, action, environment in
            switch action {
            case .startLoading:
                return fetch(environment)
                    .catchToEffect()
                    .map { Action.didFinishLoading($0) }
                    .prepend(Action.didStartLoading)
                    .eraseToEffect()
                    .cancellable(id: state.identifier, cancelInFlight: true)
            case .didStartLoading:
                state.result = nil
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
