//
//  File.swift
//  
//
//  Created by Thomas Visser on 14/01/2023.
//

import Foundation
import ComposableArchitecture

public struct Retain<Wrapped, Value>: Reducer where Wrapped: Reducer, Value: Equatable {
    let wrappedReducer: Wrapped
    let valueToRetain: (Wrapped.State) -> Value?

    public init(
        wrappedReducer: Wrapped,
        valueToRetain: @escaping (Wrapped.State) -> Value?
    ) {
        self.wrappedReducer = wrappedReducer
        self.valueToRetain = valueToRetain
    }

    @dynamicMemberLookup
    public struct State {
        public var wrapped: Wrapped.State
        public var retained: Value?

        public init(wrapped: Wrapped.State, retained: Value? = nil) {
            self.wrapped = wrapped
            self.retained = retained
        }

        public subscript<T>(dynamicMember keyPath: KeyPath<Wrapped.State, T>) -> T {
            wrapped[keyPath: keyPath]
        }

        public subscript<T>(dynamicMember keyPath: WritableKeyPath<Wrapped.State, T>) -> T {
            get { wrapped[keyPath: keyPath] }
            set { wrapped[keyPath: keyPath] = newValue }
        }
    }

    public func reduce(into state: inout State, action: Wrapped.Action) -> Effect<Wrapped.Action> {
        let previousValue = valueToRetain(state.wrapped)
        let wrappedEffect = wrappedReducer.reduce(into: &state.wrapped, action: action)
        let newValue = valueToRetain(state.wrapped)
        
        if previousValue != newValue {
            if let newValue {
                state.retained = newValue
            }
        }
        
        return wrappedEffect
    }
}

public extension Reducer{
    func retaining<Value>(
        valueToRetain: @escaping (State) -> Value?
    ) -> Retain<Self, Value> where Value: Equatable {
        Retain(wrappedReducer: self, valueToRetain: valueToRetain)
    }
}

extension Retain.State: Equatable where Wrapped.State: Equatable { }
