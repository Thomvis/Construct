//
//  AsyncReduceTest.swift
//  
//
//  Created by Thomas Visser on 12/02/2023.
//

import Foundation
import XCTest
import Helpers
import ComposableArchitecture
import AsyncAlgorithms
import Clocks

final class AsyncReduceTest: XCTestCase {

    struct TestError: Error, Equatable {
        let description: String
    }

    @MainActor
    func test() async {
        let store = TestStore(
            initialState: AsyncReduceState<Int, TestError>(value: 0),
            reducer: AsyncReduceState.reducer(
                { [0, 1, 2, 3, 4, 5].async },
                reduce: { res, val in res += val },
                mapError: { TestError(description: String(describing: $0)) }
            ),
            environment: ()
        )

        await store.send(.start(0)) {
            $0.state = .reducing
        }

        await store.receive(.onElement(0))

        await store.receive(.onElement(1)) {
            $0.value = 1
        }

        await store.receive(.onElement(2)) {
            $0.value = 3
        }

        await store.receive(.onElement(3)) {
            $0.value = 6
        }

        await store.receive(.onElement(4)) {
            $0.value = 10
        }

        await store.receive(.onElement(5)) {
            $0.value = 15
        }

        await store.receive(.didFinish) {
            $0.state = .finished
        }
    }

    @MainActor
    func testStop() async {
        let clock = TestClock()

        let store = TestStore(
            initialState: AsyncReduceState<Int, TestError>(value: 0),
            reducer: AsyncReduceState.reducer(
                {
                    AsyncThrowingStream { continuation in
                        Task {
                            do {
                                for i in 0..<10 {
                                    try await clock.sleep(for: .seconds(1))
                                    continuation.yield(i)
                                }
                                continuation.finish()
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        }
                    }
                },
                reduce: { res, val in res += val },
                mapError: { TestError(description: String(describing: $0)) }
            ),
            environment: ()
        )

        await store.send(.start(0)) {
            $0.state = .reducing
        }

        await clock.advance(by: .seconds(1.1))

        await store.receive(.onElement(0))

        await clock.advance(by: .seconds(1))

        await store.receive(.onElement(1)) {
            $0.value = 1
        }

        await clock.advance(by: .seconds(0.5))

        await store.send(.stop) {
            $0.state = .failed(TestError(description: "CancellationError()"))
        }

        await clock.advance(by: .seconds(10))
    }
}
