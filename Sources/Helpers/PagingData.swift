//
//  PagingData.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import ComposableArchitecture

public let PagingDataBatchSize = 40

@Reducer
public struct PagingData<Element> where Element: Equatable {

    @ObservableState
    public struct State: Equatable {
        fileprivate let id: UUID
        public var elements: [Element]?
        public var loadingState: LoadingState

        public init() {
            @Dependency(\.uuid) var uuid
            self.id = uuid()
            self.elements = nil
            self.loadingState = .notLoading(didReachEnd: false)
        }

        public enum LoadingState: Equatable {
            case notLoading(didReachEnd: Bool)
            case loading
            case error(PagingDataError)
        }
    }

    public enum Action: Equatable {
        case didShowElementAtIndex(Int)
        case didLoadMore(UUID, Result<FetchResult, PagingDataError>)
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

    public struct FetchRequest {
        public let offset: Int
        public let count: Int?

        public var range: Range<Int>? {
            count.map { count in offset..<(offset+count) }
        }
    }

    private let fetch: (FetchRequest) async -> Result<Action.FetchResult, PagingDataError>

    public init(
        _ fetch: @escaping (FetchRequest) async -> Result<Action.FetchResult, PagingDataError>
    ) {
        self.fetch = fetch
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            func load(_ request: FetchRequest, in state: inout State) -> Effect<Action> {
                state.loadingState = .loading
                let id = state.id
                return .run { send in
                    let result = await fetch(request)
                    await send(.didLoadMore(id, result))
                }
                .cancellable(id: state.id)
            }

            func loadIfNeeded(for idx: Int, state: inout State) -> Effect<Action> {
                let elementCount = state.elements?.count ?? 0
                guard idx > elementCount - Int((Double(PagingDataBatchSize) * 1.5)) else { return .none }
                guard state.loadingState == .notLoading(didReachEnd: false) else { return .none }
                return load(FetchRequest(offset: elementCount, count: PagingDataBatchSize), in: &state)
            }

            switch action {
            case .didShowElementAtIndex(let idx):
                return loadIfNeeded(for: idx, state: &state)
            case .didLoadMore(state.id, .success(let res)):
                state.elements = (state.elements ?? []) + res.elements
                state.loadingState = .notLoading(didReachEnd: res.end)
            case .didLoadMore(state.id, .failure(let e)):
                state.loadingState = .error(e)
            case .didLoadMore:
                // received didLoadMore with mismatched id
                // this is a work-around for Map not properly cancelling result effects
                // when the input changes
                break
            case .reload(.initial):
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)

                return .concatenate(
                    .cancel(id: state.id),
                    loadIfNeeded(for: 0, state: &state)
                )
            case .reload(.currentCount):
                let count = state.elements?.count ?? 0
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)

                if count > 0 {
                    return .concatenate(
                        .cancel(id: state.id),
                        load(FetchRequest(offset: 0, count: count), in: &state)
                    )
                } else {
                    return .concatenate(
                        .cancel(id: state.id),
                        loadIfNeeded(for: 0, state: &state)
                    )
                }
            case .reload(.all):
                state.elements = nil
                state.loadingState = .notLoading(didReachEnd: false)

                return .concatenate(
                    .cancel(id: state.id),
                    load(FetchRequest(offset: 0, count: nil), in: &state)
                )
            }
            return .none
        }
    }
}

public struct PagingDataError: Swift.Error, Equatable {
    public let description: String

    public init(describing error: any Error) {
        self.description = String(describing: error)
    }
}
