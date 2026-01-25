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
import TestSupport

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

        await store.receive(.didLoadMore(UUID(fakeSeq: 0), .success(.init(elements: Array(0..<PagingDataBatchSize), end: false)))) {
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

        await store.receive(.didLoadMore(UUID(fakeSeq: 0), .success(.init(elements: Array(PagingDataBatchSize..<(2*PagingDataBatchSize)), end: false)))) {
            $0.elements = Array(0..<2*PagingDataBatchSize)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // don't load because it's not close to the end
        await store.send(.didShowElementAtIndex(2))

        await store.send(.didShowElementAtIndex(2*PagingDataBatchSize-1)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(UUID(fakeSeq: 0), .success(.init(elements: Array((2*PagingDataBatchSize)..<defaultItemCount), end: true)))) {
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

        await store.receive(.didLoadMore(UUID(fakeSeq: 0), .success(.init(elements: Array(0..<PagingDataBatchSize), end: false)))) {
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

        await store.receive(.didLoadMore(UUID(fakeSeq: 0), .success(.init(elements: Array(0..<PagingDataBatchSize), end: false)))) {
            $0.elements = Array(0..<PagingDataBatchSize)
            $0.loadingState = .notLoading(didReachEnd: false)
        }
    }

    struct State: Equatable {
        var left: PagingData<Int>.State
        var right: PagingData<Int>.State
    }
    @CasePathable
    enum Action: Equatable {
        case left(PagingData<Int>.Action)
        case right(PagingData<Int>.Action)
    }

    @MainActor
    func testIsolation() async {
        let clock = TestClock()
        let uuidGenerator = UUIDGenerator.fake()
        let left = withDependencies {
            $0.uuid = uuidGenerator
        } operation: {
            PagingData<Int>.State()
        }
        let right = withDependencies {
            $0.uuid = uuidGenerator
        } operation: {
            PagingData<Int>.State()
        }
        let store = TestStore<State, Action>(
            initialState: State(left: left, right: right),
        ) {
            CombineReducers {
                Scope(state: \.left, action: \.left) {
                    pagingData(clock: clock)
                }
                
                Scope(state: \.right, action: \.right) {
                    pagingData(clock: clock)
                }
            }
        } withDependencies: {
            $0.uuid = uuidGenerator
        }

        await store.send(.left(.didShowElementAtIndex(0))) {
            $0.left.loadingState = .loading
        }

        await store.send(.right(.reload(.currentCount))) {
            $0.right.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.left(.didLoadMore(UUID(fakeSeq: 0), .success(.init(elements: Array(0..<PagingDataBatchSize), end: false))))) {
            $0.left.elements = Array(0..<PagingDataBatchSize)
            $0.left.loadingState = .notLoading(didReachEnd: false)
        }

        await store.receive(.right(.didLoadMore(UUID(fakeSeq: 1), .success(.init(elements: Array(0..<PagingDataBatchSize), end: false))))) {
            $0.right.elements = Array(0..<PagingDataBatchSize)
            $0.right.loadingState = .notLoading(didReachEnd: false)
        }
    }

    private func makeStore(
        clock: any Clock<Duration> = ContinuousClock(),
        elements: [Int] = Array(0..<defaultItemCount)
    ) -> TestStoreOf<PagingData<Int>> {
        let uuidGenerator = UUIDGenerator.fake()
        let state = withDependencies {
            $0.uuid = uuidGenerator
        } operation: {
            PagingData<Int>.State()
        }
        return TestStore(
            initialState: state,
        ) {
            pagingData(clock: clock, elements: elements)
        } withDependencies: {
            $0.uuid = uuidGenerator
        }
    }

    private func pagingData(
        clock: any Clock<Duration> = ContinuousClock(),
        elements: [Int] = Array(0..<defaultItemCount)
    ) -> PagingData<Int> {
        PagingData<Int> { request in
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
