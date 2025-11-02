import Helpers
import ComposableArchitecture
import XCTest

final class WithStateReducerTest: XCTestCase {
    @MainActor
    func test() async {
        struct Feature: Reducer {
            struct State: Equatable {
                var value: Int = 0
                var step: Int
            }

            enum Action: Equatable {
                case increment
                case step(Int)
            }

            var body: some ReducerOf<Self> {
                Reduce { state, action in
                    if case .step(let s) = action {
                        state.step = s
                    }
                    return .none
                }

                WithValue(value: \.step) { step in
                    return Reduce<State, Action> { state, action in
                        if action == .increment {
                            state.value = state.value + step
                        }
                        return .none
                    }
                }
            }
        }

        let feature = Feature()
        let store = TestStore(initialState: Feature.State(step: 1)) {
            feature
        }

        await store.send(.increment) { state in
            state.value = 1
        }

        await store.send(.step(2)) { state in
            state.step = 2
        }

        await store.send(.increment) { state in
            state.value = 3
        }
    }
}
