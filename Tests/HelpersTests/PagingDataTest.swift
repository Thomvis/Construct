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

final class PagingDataTest: XCTestCase {
    @MainActor
    func testLoadMoreLogic() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.didShowElementAtIndex(0)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(0..<20), end: false)))) {
            $0.elements = Array(0..<20)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // load because it's close (20) to the end
        await store.send(.didShowElementAtIndex(1)) {
            $0.loadingState = .loading
        }

        // don't load more because we're already loading
        await store.send(.didShowElementAtIndex(3))

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(20..<40), end: false)))) {
            $0.elements = Array(0..<40)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // don't load because it's not close to the end
        await store.send(.didShowElementAtIndex(2))

        await store.send(.didShowElementAtIndex(39)) {
            $0.loadingState = .loading
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.didLoadMore(.success(.init(elements: Array(40..<55), end: true)))) {
            $0.elements = Array(0..<55)
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

        await store.receive(.didLoadMore(.success(.init(elements: Array(0..<20), end: false)))) {
            $0.elements = Array(0..<20)
            $0.loadingState = .notLoading(didReachEnd: false)
        }

        // load because it's close (20) to the end
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

        await store.receive(.didLoadMore(.success(.init(elements: Array(0..<20), end: false)))) {
            $0.elements = Array(0..<20)
            $0.loadingState = .notLoading(didReachEnd: false)
        }
    }

    private func makeStore(
        state: PagingData<Int> = .init(),
        clock: any Clock<Duration> = ContinuousClock(),
        elements: [Int] = Array(0..<55)
    ) -> TestStore<PagingData<Int>, PagingDataAction<Int>, PagingData<Int>, PagingDataAction<Int>, Void> {
        TestStore(
            initialState: state,
            reducer: PagingData<Int>.reducer { request, env in
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
            },
            environment: ()
        )
    }
}
