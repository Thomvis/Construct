import Foundation
import XCTest
@testable import Helpers
import ComposableArchitecture
import Clocks

final class MapTest: XCTestCase {
    @MainActor
    func testNormalMap() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.input(.string("Construct"))) {
            $0.input.string = "Construct"
            $0.cancellationId = UUID(0)
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
            $0.counter.cancellationId = UUID(0)
        }

        await store.receive(.counter(.result(.add)))

        await store.receive(.counter(.input(.string("5e")))) {
            $0.counter.input.string = "5e"
            $0.counter.result.count = 2
            $0.counter.cancellationId = UUID(1)
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
            $0.cancellationId = UUID(0)
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
            $0.cancellationId = UUID(1)
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
    ) -> TestStoreOf<Map<Input, Result>> {
        TestStore(
            initialState: Map<Input, Result>.State(
                input: Input.State(string: ""),
                result: Result.State(count: 0)
            )
        ) {
            Map(
                inputReducer: Input(),
                initialResultStateForInput: { _ in Result.State(count: 0) },
                initialResultActionForInput: { Result.Action.count($0.string.count) },
                resultReducerForInput: { Result(count: $0.string.count, clock: clock) }
            )
        } withDependencies: { dependencies in
            dependencies.uuid = UUIDGenerator.incrementing
        }
    }

    private func makeStore2(
        clock: any Clock<Duration>
    ) -> TestStoreOf<Container> {
        TestStore(
            initialState: Container.State(
                counter: Map<Input, Result>.State(
                    input: Input.State(string: ""),
                    result: Result.State(count: 0)
                )
            )
        ) {
            Container(clock: clock)
        } withDependencies: { dependencies in
            dependencies.uuid = UUIDGenerator.incrementing
        }
    }

    struct Container: Reducer {
        let clock: any Clock<Duration>

        struct State: Equatable {
            var counter: Map<Input, Result>.State
        }

        enum Action: Equatable {
            case triggerTwoInputChanges
            case counter(Map<Input, Result>.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: \.counter, action: /Action.counter) {
                Map(
                    inputReducer: Input(),
                    initialResultStateForInput: { Result.State(count: $0.string.count) },
                    initialResultActionForInput: { _ in Result.Action.add },
                    resultReducerForInput: { Result(count: $0.string.count, clock: clock) }
                )
            }

            Reduce { state, action in
                switch action {
                case .triggerTwoInputChanges:
                    return .run { send in
                        await send(Action.counter(.input(.string("Construct"))))
                        await send(Action.counter(.input(.string("5e"))))
                    }
                case .counter: break
                }
                return .none
            }
        }
    }


    struct Input: Reducer {
        struct State: Equatable {
            var string: String
        }

        enum Action: Equatable {
            case string(String)
        }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .string(let s):
                state.string = s
            }
            return .none
        }
    }

    struct Result: Reducer {
        struct State: Equatable {
            var count: Int
        }

        enum Action: Equatable {
            case add
            case remove
            case count(Int)
        }

        let count: Int
        let clock: any Clock<Duration>

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .add:
                let res = state.count + count
                return .run { send in
                    try await clock.sleep(for: .seconds(1))
                    await send(.count(res))
                }
            case .remove:
                let res = state.count - count
                return .run { send in
                    try await clock.sleep(for: .seconds(1))
                    await send(.count(res))
                }
            case .count(let c):
                state.count = c
            }
            return .none
        }
    }

}
