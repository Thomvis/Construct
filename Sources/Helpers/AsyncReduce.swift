//
//  AsyncReduce.swift
//  
//
//  Created by Thomas Visser on 12/02/2023.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct AsyncReduce<Result, Element, Failure> where Failure: Error {

    public struct State {
        fileprivate let id = UUID()
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
            case stopped
        }
    }

    public enum Action {
        case start(Result)
        case onElement(Element)
        case onError(Failure)
        case didFinish
        case stop
    }

    private let sequence: () throws -> AnyAsyncSequence<Element>
    private let reduce: (inout Result, Element) -> Void
    private let mapError: (Error) -> Failure

    public init<S>(
        _ sequence: @escaping () throws -> S,
        reduce: @escaping (inout Result, Element) -> Void,
        mapError: @escaping (Error) -> Failure
    ) where S: AsyncSequence, S.Element == Element {
        self.sequence = { try AnyAsyncSequence(wrapping: sequence()) }
        self.reduce = reduce
        self.mapError = mapError
    }

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .start(let res):
            state.value = res
            state.state = .reducing
            return .run { send in
                do {
                    for try await elem in try sequence() {
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
                state.state = .stopped
            }
            return .cancel(id: state.id)
        }
        return .none
    }
}


extension AsyncReduce.State: Equatable where Result: Equatable, Failure: Equatable { }

extension AsyncReduce.State.State: Equatable where Failure: Equatable { }

extension AsyncReduce.Action: Equatable where Result: Equatable, Failure: Equatable, Element: Equatable { }

extension AsyncReduce.State {
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

    public var isFinished: Bool {
        if case .finished = state {
            return true
        }
        return false
    }
}

// from https://github.com/apple/swift-nio/blob/56f9b7c6fc9525ba36236dbb151344f8c35288df/Sources/NIOFileSystem/Internal/BufferedOrAnyStream.swift#L71C1-L96C2
// work around issue where iOS 18 added Failure, breaking compatibility with iOS 17 and below
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AnyAsyncSequence<Element>: AsyncSequence {
    private let _makeAsyncIterator: () -> AsyncIterator

    internal init<S: AsyncSequence>(wrapping sequence: S) where S.Element == Element {
        self._makeAsyncIterator = {
            AsyncIterator(wrapping: sequence.makeAsyncIterator())
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        self._makeAsyncIterator()
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: any AsyncIteratorProtocol

        init<I: AsyncIteratorProtocol>(wrapping iterator: I) where I.Element == Element {
            self.iterator = iterator
        }

        public mutating func next() async throws -> Element? {
            try await self.iterator.next() as? Element
        }
    }
}
