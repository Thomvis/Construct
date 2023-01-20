//
//  PagingData.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import ComposableArchitecture

private let assumedNumberOfItemsOnScreen = 20

public struct PagingData<Element>: Equatable where Element: Equatable {
    private let id = UUID()
    public var elements: [Element]?
    public var loadingState: LoadingState

    public init() {
        self.elements = nil
        self.loadingState = .notLoading(didReachEnd: false)
    }

    public enum LoadingState: Equatable {
        case notLoading(didReachEnd: Bool)
        case loading
        case error(PagingDataError)
    }
}

public enum PagingDataAction<Element>: Equatable where Element: Equatable {
    case didShowElementAtIndex(Int)
    case didLoadMore(Result<FetchResult, PagingDataError>)
    case reload

    public struct FetchResult: Equatable {
        let elements: [Element]
        let end: Bool

        public init(elements: [Element], end: Bool) {
            self.elements = elements
            self.end = end
        }
    }
}

public struct PagingDataError: Swift.Error, Equatable {
    public let description: String

    public init(describing error: any Error) {
        self.description = String(describing: error)
    }
}

private enum LoadID { }

public extension PagingData {
    static func reducer<Environment>(
        _ fetch: @escaping (Int, Environment) async -> Result<PagingDataAction<Element>.FetchResult, PagingDataError>
    ) -> AnyReducer<Self, PagingDataAction<Element>, Environment> {
        return AnyReducer { state, action, env in

            func loadIfNeeded(for idx: Int, state: inout Self) -> EffectTask<PagingDataAction<Element>> {
                let elementCount = state.elements?.count ?? 0
                guard idx > elementCount - assumedNumberOfItemsOnScreen else { return .none }
                guard state.loadingState == .notLoading(didReachEnd: false) else { return .none }
                state.loadingState = .loading
                return .task {
                    let result = await fetch(elementCount, env)
                    return .didLoadMore(result)
                }
                // work-around for issue https://github.com/pointfreeco/swift-composable-architecture/issues/1848
                // when used inside a MapState
                .eraseToEffect()
                .cancellable(id: LoadID.self)
            }

            switch action {
            case .didShowElementAtIndex(let idx):
                return loadIfNeeded(for: idx, state: &state)
            case .didLoadMore(.success(let res)):
                state.elements = (state.elements ?? []) + res.elements
                state.loadingState = .notLoading(didReachEnd: res.end)
            case .didLoadMore(.failure(let e)):
                state.loadingState = .error(e)
            case .reload:
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)
                return loadIfNeeded(for: 0, state: &state)
                    .prepend(EffectTask.cancel(id: LoadID.self))
                    .eraseToEffect()
            }
            return .none
        }
    }
}

