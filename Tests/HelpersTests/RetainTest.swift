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

    func test() {
        let store = TestStore(
            initialState: RetainState(wrapped: Async.loaded(0)),
            reducer: RetainState.reducer(
                wrappedReducer: Async.reducer,
                valueToRetain: \.value
            ),
            environment: ()
        )

        store.send(.startLoading) {
            $0.wrapped = .loading
        }

        store.send(.didLoad(2)) {
            $0.wrapped = .loaded(2)
            $0.retained = 2
        }

        store.send(.startLoading) {
            $0.wrapped = .loading
        }
    }

    enum Async: Equatable {
        case loaded(Int)
        case loading

        var value: Int? {
            if case .loaded(let i) = self {
                return i
            }
            return nil
        }

        static let reducer = AnyReducer<Self, AsyncAction, Void> { state, action, _ in
            switch action {
            case .startLoading:
                state = .loading
            case .didLoad(let res):
                state = .loaded(res)
            }
            return .none
        }
    }

    enum AsyncAction {
        case startLoading
        case didLoad(Int)
    }

}
