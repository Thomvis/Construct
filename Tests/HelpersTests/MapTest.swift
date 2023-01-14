//
//  MapTest.swift
//  
//
//  Created by Thomas Visser on 14/01/2023.
//

import Foundation

import Foundation
import XCTest
import Helpers
import ComposableArchitecture
import Clocks

final class MapTest: XCTestCase {
    @MainActor
    func testNormalMap() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.input(.string("Construct"))) {
            $0.input.string = "Construct"
        }

        await store.receive(.result(.count(9))) {
            $0.result.count = 9
        }

        await store.send(.result(.add))
        await clock.advance(by: .seconds(1))

        await store.receive(.result(.count(18))) {
            $0.result.count = 18
        }
    }

    @MainActor
    func testCancellation() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.input(.string("Construct"))) {
            $0.input.string = "Construct"
        }

        await store.receive(.result(.count(9))) {
            $0.result.count = 9
        }

        await store.send(.result(.add)) // this action will be cancelled

        // before the add is processed (it has a 1 sec sleep) we change the input
        await clock.advance(by: .milliseconds(500))

        await store.send(.input(.string("5e"))) {
            $0.input.string = "5e"
            $0.result.count = 0
        }

        await store.receive(.result(.count(2))) {
            $0.result.count = 2
        }

        await clock.advance(by: .seconds(1)) // .add should still have had no effect

        await store.send(.result(.add))
        await clock.advance(by: .seconds(1))

        await store.receive(.result(.count(4))) {
            $0.result.count = 4
        }
    }

    private func makeStore(
        clock: any Clock<Duration>
    ) -> TestStore<MapState<Input, Result>, MapState<Input, Result>, MapAction<InputAction, ResultAction>, MapAction<InputAction, ResultAction>, Environment> {
        TestStore(
            initialState: MapState(
                input: Input(string: ""),
                result: Result(count: 0)
            ),
            reducer: MapState.reducer(
                inputReducer: Input.reducer,
                initialResultStateForInput: { _ in Result(count: 0) },
                initialResultActionForInput: { ResultAction.count($0.string.count) },
                resultReducerForInput: { Result.reducer(count: $0.string.count) }
            ),
            environment: Environment(clock: clock)
        )
    }

    struct Input: Equatable {
        var string: String

        static let reducer = Reducer<Self, InputAction, Environment> { state, action, env in
            switch action {
            case .string(let s):
                state.string = s
            }
            return .none
        }
    }

    struct Result: Equatable {
        var count: Int

        static func reducer(count: Int) -> Reducer<Self, ResultAction, Environment> {
            Reducer { state, action, env in
                switch action {
                case .add:
                    let res = state.count + count
                    return Effect.run { send in
                        try await env.clock.sleep(for: .seconds(1))
                        await send(.count(res))
                    }
                case .remove:
                    let res = state.count - count
                    return Effect.run { send in
                        try await env.clock.sleep(for: .seconds(1))
                        await send(.count(res))
                    }
                case .count(let c):
                    state.count = c
                }
                return .none
            }
        }
    }

    enum InputAction: Equatable {
        case string(String)
    }

    enum ResultAction: Equatable {
        case add
        case remove
        case count(Int)
    }

    struct Environment {
        let clock: any Clock<Duration>
    }
}
