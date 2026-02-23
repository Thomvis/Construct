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
@Reducer
public struct Async<Success, Failure> where Failure: Error {

    public let fetch: () async throws -> Success

    public init(fetch: @escaping () async throws -> Success) {
        self.fetch = fetch
    }

    public struct State {
        var identifier: UUID
        public var isLoading: Bool
        public var result: Result<Success, Failure>?

        public init(identifier: UUID = UUID(), isLoading: Bool = false, result: Result<Success, Failure>? = nil) {
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

        public static var initial: State {
            State()
        }
    }

    public enum Action {
        case startLoading
        case didStartLoading
        case didFinishLoading(Result<Success, Failure>)
        case reset
    }

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startLoading:
            return .run { send in
                await send(.didStartLoading)
                do {
                    try await send(.didFinishLoading(.success(fetch())))
                } catch let error as Failure {
                    await send(.didFinishLoading(.failure(error)))
                }
            }
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

extension Async.State: Equatable where Success: Equatable, Failure: Equatable {

}

extension Async.Action: Equatable where Success: Equatable, Failure: Equatable {

}
