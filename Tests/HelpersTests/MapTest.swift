//
//  MapTest.swift
//  
//
//  Created by Thomas Visser on 14/01/2023.
//

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

    /// Test fails because Effect.cancel doesn't work as fast as I assumed
    /// It does not cancel an effect that has been emitted but not yet subscribed to
    @MainActor
    func testImmediateCancellation() async {
        let clock = TestClock()
        let store = makeStore2(clock: clock)

        await store.send(.triggerTwoInputChanges)

        await store.receive(.counter(.input(.string("Construct")))) {
            $0.counter.input.string = "Construct"
            $0.counter.result.count = 9
        }

        await store.receive(.counter(.result(.add)))

        await store.receive(.counter(.input(.string("5e")))) {
            $0.counter.input.string = "5e"
            $0.counter.result.count = 2
        }

        await store.receive(.counter(.result(.add)))

        await clock.advance(by: .seconds(1))

        await store.receive(.counter(.result(.count(4)))) {
            $0.counter.result.count = 4
        }
    }

    @MainActor
    func testDelayedCancellation() async {
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
    ) -> TestStore<MapState<Input, Result>, MapAction<Input, InputAction, Result, ResultAction>, MapState<Input, Result>, MapAction<Input, InputAction, Result, ResultAction>, Environment> {
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

    private func makeStore2(
        clock: any Clock<Duration>
    ) -> TestStore<Container, ContainerAction, Container, ContainerAction, Environment> {
        TestStore(
            initialState: Container(
                counter: MapState(
                    input: Input(string: ""),
                    result: Result(count: 0)
                )
            ),
            reducer: Container.reducer,
            environment: Environment(clock: clock)
        )
    }

    struct Container: Equatable {
        var counter: MapState<Input, Result>

        static let reducer = AnyReducer.combine(
            MapState.reducer(
                inputReducer: Input.reducer,
                initialResultStateForInput: { Result(count: $0.string.count) },
                initialResultActionForInput: { _ in ResultAction.add },
                resultReducerForInput: { Result.reducer(count: $0.string.count) }
            ).pullback(state: \.counter, action: /ContainerAction.counter),
            AnyReducer<Self, ContainerAction, Environment> { state, action, env in
                switch action {
                case .triggerTwoInputChanges:
                    return Effect.run { send in
                        await send(ContainerAction.counter(.input(.string("Construct"))))
                        await send(ContainerAction.counter(.input(.string("5e"))))
                    }
                default: break
                }
                return .none
            }
        )
    }

    enum ContainerAction: Equatable {
        case triggerTwoInputChanges
        case counter(MapAction<Input, InputAction, Result, ResultAction>)
    }

    struct Input: Equatable {
        var string: String

        static let reducer = AnyReducer<Self, InputAction, Environment> { state, action, env in
            switch action {
            case .string(let s):
                state.string = s
            }
            return .none
        }
    }

    struct Result: Equatable {
        var count: Int

        static func reducer(count: Int) -> AnyReducer<Self, ResultAction, Environment> {
            AnyReducer { state, action, env in
                switch action {
                case .add:
                    let res = state.count + count
                    return Effect.run { send in
                        try await env.clock.sleep(for: .seconds(1))
                        await send(.count(res))
                    }
                    // work-around for issue https://github.com/pointfreeco/swift-composable-architecture/issues/1848
                    .eraseToEffect()
                case .remove:
                    let res = state.count - count
                    return Effect.run { send in
                        try await env.clock.sleep(for: .seconds(1))
                        await send(.count(res))
                    }
                    // work-around for issue https://github.com/pointfreeco/swift-composable-architecture/issues/1848
                    .eraseToEffect()
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
