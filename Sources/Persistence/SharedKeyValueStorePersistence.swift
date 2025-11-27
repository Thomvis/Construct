//
//  SharedKeyValueStorePersistence.swift
//  Persistence
//
//  Custom persistence strategy for TCA's @Shared using KeyValueStore
//

import Foundation
import Sharing
import ComposableArchitecture

// MARK: - KeyValueStorePersistenceKey

/// A persistence key that stores values in `KeyValueStore`.
///
/// Use this with TCA's `@Shared` to persist state to the database:
/// ```swift
/// @Shared(.keyValueStore("myKey")) var myValue: MyValue = .defaultValue
/// ```
public struct KeyValueStorePersistenceKey<Value: Codable & Equatable & Sendable>: SharedKey {
    public typealias ID = String

    private let key: String
    private let store: @Sendable () -> KeyValueStore

    public var id: ID { key }

    /// Creates a persistence key for the given key string.
    /// - Parameters:
    ///   - key: The key under which to store the value
    ///   - store: A closure that returns the KeyValueStore to use.
    public init(
        _ key: String,
        store: @escaping @Sendable () -> KeyValueStore
    ) {
        self.key = key
        self.store = store
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        do {
            if let loaded: Value = try store().get(key) {
                continuation.resume(returning: loaded)
            } else {
                continuation.resumeReturningInitialValue()
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }

    public func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
        do {
            try store().put(value, at: key)
            continuation.resume()
        } catch {
            continuation.resume(throwing: error)
        }
    }

    public func subscribe(
        context: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let keyValueStore = store()
        let stream: AsyncThrowingStream<Value?, any Error> = keyValueStore.observe(key)

        let task = Task {
            do {
                for try await value in stream {
                    if let value {
                        subscriber.yield(with: .success(value))
                    } else if let initialValue = context.initialValue {
                        subscriber.yield(with: .success(initialValue))
                    }
                }
            } catch {
                // Stream ended or errored - subscription ends naturally
            }
        }

        return SharedSubscription {
            task.cancel()
        }
    }
}

// MARK: - Convenience extension

public extension SharedReaderKey {
    /// Creates a persistence key that stores values in the database's KeyValueStore.
    ///
    /// Usage:
    /// ```swift
    /// @Shared(.keyValueStore("settings.theme")) var theme: Theme = .light
    /// ```
    ///
    /// - Parameters:
    ///   - key: The key under which to store the value
    ///   - store: A closure returning the KeyValueStore. Defaults to database dependency.
    static func keyValueStore<Value: Codable & Equatable & Sendable>(
        _ key: String,
        store: @escaping @Sendable () -> KeyValueStore = {
            @Dependency(\.database) var database
            return database.keyValueStore
        }
    ) -> Self where Self == KeyValueStorePersistenceKey<Value> {
        KeyValueStorePersistenceKey(key, store: store)
    }
}

// MARK: - Entity-based persistence key

/// A persistence key for `KeyValueStoreEntity` types that uses the entity's key.
public struct KeyValueStoreEntityPersistenceKey<Value: KeyValueStoreEntity & Equatable & Sendable>: SharedKey {
    public typealias ID = String

    private let entityKey: Value.Key
    private let store: @Sendable () -> KeyValueStore

    public var id: ID { entityKey.rawValue }

    public init(
        _ entityKey: Value.Key,
        store: @escaping @Sendable () -> KeyValueStore
    ) {
        self.entityKey = entityKey
        self.store = store
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        do {
            if let loaded: Value = try store().get(entityKey) {
                continuation.resume(returning: loaded)
            } else {
                continuation.resumeReturningInitialValue()
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }

    public func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
        do {
            try store().put(value)
            continuation.resume()
        } catch {
            continuation.resume(throwing: error)
        }
    }

    public func subscribe(
        context: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let keyValueStore = store()
        let stream: AsyncThrowingStream<Value?, any Error> = keyValueStore.observe(entityKey.rawValue)

        let task = Task {
            do {
                for try await value in stream {
                    if let value {
                        subscriber.yield(with: .success(value))
                    } else if let initialValue = context.initialValue {
                        subscriber.yield(with: .success(initialValue))
                    }
                }
            } catch {
                // Stream ended or errored
            }
        }

        return SharedSubscription {
            task.cancel()
        }
    }
}

public extension SharedReaderKey {
    /// Creates a persistence key for a `KeyValueStoreEntity` using its entity key.
    ///
    /// Usage:
    /// ```swift
    /// @Shared(.entity(Preferences.key)) var preferences: Preferences = .init()
    /// ```
    static func entity<Value: KeyValueStoreEntity & Equatable & Sendable>(
        _ entityKey: Value.Key,
        store: @escaping @Sendable () -> KeyValueStore = {
            @Dependency(\.database) var database
            return database.keyValueStore
        }
    ) -> Self where Self == KeyValueStoreEntityPersistenceKey<Value> {
        KeyValueStoreEntityPersistenceKey(entityKey, store: store)
    }
}
