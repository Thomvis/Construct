//
//  PagingDataTest.swift
//  
//
//  Created by Thomas Visser on 13/01/2023.
//

import Foundation
import XCTest
import Helpers
import ComposableArchitecture
import Clocks

let defaultItemCount = 2*PagingDataBatchSize+10

final class PagingDataTest: XCTestCase {

    @MainActor
    func testLoadMoreLogic() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.didShowElementAtIndex(0)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(0..<PagingDataBatchSize), end: false)))) {
            $0.elements = Array(0..<PagingDataBatchSize)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // load because it's close to the end
        await store.send(.didShowElementAtIndex(1)) {
            $0.loadingState = .loading
        }

        // don't load more because we're already loading
        await store.send(.didShowElementAtIndex(3))

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(PagingDataBatchSize..<(2*PagingDataBatchSize)), end: false)))) {
            $0.elements = Array(0..<2*PagingDataBatchSize)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // don't load because it's not close to the end
        await store.send(.didShowElementAtIndex(2))

        await store.send(.didShowElementAtIndex(2*PagingDataBatchSize-1)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array((2*PagingDataBatchSize)..<defaultItemCount), end: true)))) {
            $0.elements = Array(0..<defaultItemCount)
            $0.loadingState = .notLoading(didReachEnd: true)
        }

        await store.finish()
    }

    @MainActor
    func testReload() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.didShowElementAtIndex(0)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(0..<PagingDataBatchSize), end: false)))) {
            $0.elements = Array(0..<PagingDataBatchSize)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // load because it's close to the end
        await store.send(.didShowElementAtIndex(1)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .milliseconds(100))

        // reload while loading more
        await store.send(.reload(.initial)) {
            $0.elements = nil
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(0..<PagingDataBatchSize), end: false)))) {
            $0.elements = Array(0..<PagingDataBatchSize)
            $0.loadingState = .notLoading(didReachEnd: false)
        }
    }

    @MainActor
    func testIsolation() async {
        struct State: Equatable {
            var left: PagingData<Int>
            var right: PagingData<Int>
        }
        enum Action: Equatable {
            case left(PagingDataAction<Int>)
            case right(PagingDataAction<Int>)
        }

        let clock = TestClock()
        let store = TestStore(
            initialState: State(left: .init(), right: .init()),
            reducer: AnyReducer<State, Action, Void>.combine(
                pagingDataReducer(clock: clock).pullback(state: \.left, action: /Action.left),
                pagingDataReducer(clock: clock).pullback(state: \.right, action: /Action.right),
            ),
            environment: ()
        )

        await store.send(.left(.didShowElementAtIndex(0))) {
            $0.left.loadingState = .loading
        }

        await store.send(.right(.reload(.currentCount))) {
            $0.right.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.left(.didLoadMore(.success(.init(elements: Array(0..<PagingDataBatchSize), end: false))))) {
            $0.left.elements = Array(0..<PagingDataBatchSize)
            $0.left.loadingState = .notLoading(didReachEnd: false)
        }

        await store.receive(.right(.didLoadMore(.success(.init(elements: Array(0..<PagingDataBatchSize), end: false))))) {
            $0.right.elements = Array(0..<PagingDataBatchSize)
            $0.right.loadingState = .notLoading(didReachEnd: false)
        }
    }

    private func makeStore(
        state: PagingData<Int> = .init(),
        clock: any Clock<Duration> = ContinuousClock(),
        elements: [Int] = Array(0..<defaultItemCount)
    ) -> TestStore<PagingData<Int>, PagingDataAction<Int>, PagingData<Int>, PagingDataAction<Int>, Void> {
        TestStore(
            initialState: state,
            reducer: pagingDataReducer(clock: clock, elements: elements),
            environment: ()
        )
    }

    private func pagingDataReducer(
        clock: any Clock<Duration> = ContinuousClock(),
        elements: [Int] = Array(0..<defaultItemCount)
    ) -> AnyReducer<PagingData<Int>, PagingDataAction<Int>, Void> {
        PagingData<Int>.reducer { request, env in
            do {
                try await clock.sleep(for: .seconds(1))
                let offsetted = elements.dropFirst(request.offset)
                return .success(.init(
                    elements: request.count.map { Array(offsetted.prefix($0)) } ?? Array(offsetted),
                    end: request.count.map { offsetted.count < $0 } ?? true
                ))
            } catch {
                return .failure(.init(describing: error))
            }
        }
    }
}
