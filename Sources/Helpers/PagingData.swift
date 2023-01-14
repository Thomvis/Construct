//
//  PagingData.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import ComposableArchitecture

public struct PagingData<Element>: Equatable where Element: Equatable {
    public var elements: [Element]
    public var loadingState: LoadingState

    public init() {
        self.elements = []
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

public extension PagingData {
    static func reducer<Environment>(
        _ fetch: @escaping (Int, Environment) async -> Result<PagingDataAction<Element>.FetchResult, PagingDataError>
    ) -> Reducer<Self, PagingDataAction<Element>, Environment> {
        return Reducer { state, action, env in
            switch action {
            case .didShowElementAtIndex(let idx):
                guard idx > state.elements.count - 20 || idx > Int(Double(state.elements.count)*0.8) else { break }
                guard state.loadingState == .notLoading(didReachEnd: false) else { break }
                state.loadingState = .loading
                let offset = state.elements.count
                return Effect.run(operation: { send in
                    let result = await fetch(offset, env)
                    await send(.didLoadMore(result))
                })
            case .didLoadMore(.success(let res)):
                state.elements += res.elements
                state.loadingState = .notLoading(didReachEnd: res.end)
            case .didLoadMore(.failure(let e)):
                state.loadingState = .error(e)
            }
            return .none
        }
    }
}

