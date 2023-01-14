//
//  File.swift
//  
//
//  Created by Thomas Visser on 14/01/2023.
//

import Foundation
import ComposableArchitecture

@dynamicMemberLookup
public struct RetainState<Wrapped, Value> where Value: Equatable {
    public var wrapped: Wrapped
    public var retained: Value?

    public init(wrapped: Wrapped, retained: Value? = nil) {
        self.wrapped = wrapped
        self.retained = retained
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Wrapped, T>) -> T {
        wrapped[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Wrapped, T>) -> T {
        get { wrapped[keyPath: keyPath] }
        set { wrapped[keyPath: keyPath] = newValue }
    }
}

public extension RetainState {
    static func reducer<Action, Environment>(
        wrappedReducer: Reducer<Wrapped, Action, Environment>,
        valueToRetain: @escaping (Wrapped) -> Value?
    ) -> Reducer<Self, Action, Environment> {
        wrappedReducer
            .pullback(state: \.wrapped, action: CasePath.`self`)
            .onChange(of: { valueToRetain($0.wrapped) }) { value, state, action, env in
                if let value {
                    state.retained = value
                }
                return .none
            }

    }
}

extension RetainState: Equatable where Wrapped: Equatable { }
