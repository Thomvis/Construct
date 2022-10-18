//
//  AsyncMapErrorSequence.swift
//  
//
//  Created by Thomas Visser on 16/10/2022.
//

/// based on https://github.com/apple/swift/blob/main/stdlib/public/Concurrency/AsyncMapSequence.swift

extension AsyncSequence {

    @preconcurrency
    @inlinable
    public __consuming func mapError(
        _ transform: @Sendable @escaping (Error) async -> Error
    ) -> AsyncMapErrorSequence<Self> {
        return AsyncMapErrorSequence(self, transform: transform)
    }
}

/// An asynchronous sequence that maps the given closure over the asynchronous
/// sequence’s error.
public struct AsyncMapErrorSequence<Base: AsyncSequence> {
    @usableFromInline
    let base: Base

    @usableFromInline
    let transform: (Error) async -> Error

    @usableFromInline
    init(
        _ base: Base,
        transform: @escaping (Error) async -> Error
    ) {
        self.base = base
        self.transform = transform
    }
}

extension AsyncMapErrorSequence: AsyncSequence {
    /// The type of element produced by this asynchronous sequence.
    ///
    /// The map sequence produces whatever type of element its transforming
    /// closure produces.
    public typealias Element = Base.Element
    /// The type of iterator that produces elements of the sequence.
    public typealias AsyncIterator = Iterator

    /// The iterator that produces elements of the map sequence.
    public struct Iterator: AsyncIteratorProtocol {
        @usableFromInline
        var baseIterator: Base.AsyncIterator

        @usableFromInline
        let transform: (Error) async -> Error

        @usableFromInline
        init(
            _ baseIterator: Base.AsyncIterator,
            transform: @escaping (Error) async -> Error
        ) {
            self.baseIterator = baseIterator
            self.transform = transform
        }

        /// Produces the next element in the map sequence.
        ///
        /// This iterator calls `next()` on its base iterator; if this call returns
        /// `nil`, `next()` returns `nil`. Otherwise, `next()` returns the result of
        /// calling the transforming closure on the received element.
        @inlinable
        public mutating func next() async rethrows -> Base.Element? {
            do {
                return try await baseIterator.next()
            } catch {
                throw await transform(error)
            }
        }
    }

    @inlinable
    public __consuming func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), transform: transform)
    }
}

//extension AsyncMapSequence: @unchecked Sendable
//where Base: Sendable,
//      Base.Element: Sendable,
//      Transformed: Sendable { }
//
//@available(SwiftStdlib 5.1, *)
//extension AsyncMapSequence.Iterator: @unchecked Sendable
//where Base.AsyncIterator: Sendable,
//      Base.Element: Sendable,
//      Transformed: Sendable { }
