//
//  RetainTest.swift
//  
//
//  Created by Thomas Visser on 14/01/2023.
//

import Foundation

import Foundation
import XCTest
import Helpers
import ComposableArchitecture

final class RetainTest: XCTestCase {

    struct Async: Reducer {
        enum State: Equatable {
            case loaded(Int)
            case loading

            var value: Int? {
                if case .loaded(let i) = self {
                    return i
                }
                return nil
            }
        }

        enum Action {
            case startLoading
            case didLoad(Int)
        }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .startLoading:
                state = .loading
            case .didLoad(let res):
                state = .loaded(res)
            }
            return .none
        }
    }

    @MainActor
    func test() async {
        let store = TestStore(
            initialState: Retain<Async, Int>.State(wrapped: .loaded(0))
        ) {
            Retain<Async, Int>(
                wrappedReducer: Async(),
                valueToRetain: \.value
            )
        }

        await store.send(.startLoading) {
            $0.wrapped = .loading
        }

        await store.send(.didLoad(2)) {
            $0.wrapped = .loaded(2)
            $0.retained = 2
        }

        await store.send(.startLoading) {
            $0.wrapped = .loading
        }
    }

}
