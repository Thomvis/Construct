//
//  PagingData.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import ComposableArchitecture

private let assumedNumberOfItemsOnScreen = 40

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
    case reload(ReloadScope)

    public struct FetchResult: Equatable {
        let elements: [Element]
        let end: Bool

        public init(elements: [Element], end: Bool) {
            self.elements = elements
            self.end = end
        }
    }

    public enum ReloadScope: Equatable {
        case initial // loads the initial batch
        case currentCount // loads the same amount of items it currently has, but at least initial
        case all // loads all elements at once
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
    struct FetchRequest {
        public let offset: Int
        public let count: Int?

        public var range: Range<Int>? {
            count.map { count in offset..<(offset+count) }
        }
    }
    
    static func reducer<Environment>(
        _ fetch: @escaping (FetchRequest, Environment) async -> Result<PagingDataAction<Element>.FetchResult, PagingDataError>
    ) -> AnyReducer<Self, PagingDataAction<Element>, Environment> {
        return AnyReducer { state, action, env in

            func load(_ request: FetchRequest, in state: inout Self) -> EffectTask<PagingDataAction<Element>> {
                state.loadingState = .loading
                return .task {
                    let result = await fetch(request, env)
                    return .didLoadMore(result)
                }
                // work-around for issue https://github.com/pointfreeco/swift-composable-architecture/issues/1848
                // when used inside a MapState
                .eraseToEffect()
                .cancellable(id: LoadID.self)
            }

            func loadIfNeeded(for idx: Int, state: inout Self) -> EffectTask<PagingDataAction<Element>> {
                let elementCount = state.elements?.count ?? 0
                guard idx > elementCount - Int((Double(assumedNumberOfItemsOnScreen) * 1.5)) else { return .none }
                guard state.loadingState == .notLoading(didReachEnd: false) else { return .none }
                return load(FetchRequest(offset: elementCount, count: assumedNumberOfItemsOnScreen), in: &state)
            }

            switch action {
            case .didShowElementAtIndex(let idx):
                return loadIfNeeded(for: idx, state: &state)
            case .didLoadMore(.success(let res)):
                state.elements = (state.elements ?? []) + res.elements
                state.loadingState = .notLoading(didReachEnd: res.end)
            case .didLoadMore(.failure(let e)):
                state.loadingState = .error(e)
            case .reload(.initial):
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)

                return loadIfNeeded(for: 0, state: &state)
                    .prepend(EffectTask.cancel(id: LoadID.self))
                    .eraseToEffect()
            case .reload(.currentCount):
                let count = state.elements?.count ?? 0
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)

                if count > 0 {
                    return load(FetchRequest(offset: 0, count: count), in: &state)
                        .prepend(EffectTask.cancel(id: LoadID.self))
                        .eraseToEffect()
                } else {
                    return loadIfNeeded(for: 0, state: &state)
                        .prepend(EffectTask.cancel(id: LoadID.self))
                        .eraseToEffect()
                }
            case .reload(.all):
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)

                return load(FetchRequest(offset: 0, count: nil), in: &state)
                    .prepend(EffectTask.cancel(id: LoadID.self))
                    .eraseToEffect()
            }
            return .none
        }
    }
}

