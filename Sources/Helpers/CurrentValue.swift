//
//  CurrentValue.swift
//  
//
//  Created by Thomas Visser on 23/12/2022.
//

import Foundation

/// Iterates over an AsyncStream and stores the latest element
/// to provide synchronous access to it.
public final class CurrentValue<Element> {

    private var task: Task<Void, Never>?
    private var _value: Element
    private var error: (any Error)?

    public init<Failure: Error>(initialValue: Element, updates: AsyncThrowingStream<Element, Failure>) {
        self._value = initialValue
        self.task = Task { [weak self] in
            do {
                for try await e in updates {
                    guard let self else { break }

                    self._value = e

                    if Task.isCancelled { break }
                }
            } catch {
                if let self {
                    self.error = error
                }
            }
        }
    }

    public var value: Element {
        get throws {
            if let error {
                throw error
            }
            return _value
        }
    }

    deinit {
        task?.cancel()
    }
}

public extension CurrentValue {
    static func constant(_ element: Element) -> CurrentValue<Element> {
        CurrentValue(initialValue: element, updates: AsyncThrowingStream.never)
    }
}

public extension CurrentValue where Element: OptionalProtocol {
    static var none: CurrentValue<Element> {
        Self.constant(Element.emptyOptional())
    }
}

public extension AsyncThrowingStream {
    func currentValue(_ initialValue: Element) -> CurrentValue<Element> {
        CurrentValue(initialValue: initialValue, updates: self)
    }
}
