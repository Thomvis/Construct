//
//  SharedKeyValueStorePersistenceTests.swift
//  PersistenceTests
//

import Testing
import Foundation
import Sharing
import ComposableArchitecture
@testable import Persistence
import GameModels

@MainActor
struct SharedKeyValueStorePersistenceTests {

    // MARK: - KeyValueStorePersistenceKey Tests

    @Test
    func loadReturnsInitialValueWhenNoStoredValue() async throws {
        let db = try await Database(path: nil)

        @Shared(.keyValueStore("test.missing", store: { db.keyValueStore }))
        var value: String = "default"

        #expect(value == "default")
    }

    @Test
    func loadReturnsStoredValue() async throws {
        let db = try await Database(path: nil)

        // Store a value first
        try db.keyValueStore.put("stored", at: "test.stored")

        @Shared(.keyValueStore("test.stored", store: { db.keyValueStore }))
        var value: String = "default"

        #expect(value == "stored")
    }

    @Test
    func saveWritesToStore() async throws {
        let db = try await Database(path: nil)

        @Shared(.keyValueStore("test.save", store: { db.keyValueStore }))
        var value: String = "initial"

        $value.withLock { $0 = "updated" }

        // Give time for save to complete
        try await Task.sleep(for: .milliseconds(50))

        let stored: String? = try db.keyValueStore.get("test.save")
        #expect(stored == "updated")
    }

    @Test
    func subscribeReceivesExternalUpdates() async throws {
        let db = try await Database(path: nil)

        @Shared(.keyValueStore("test.subscribe", store: { db.keyValueStore }))
        var value: String = "initial"

        // Give time for subscription to set up
        try await Task.sleep(for: .milliseconds(50))

        // Update externally
        try db.keyValueStore.put("external", at: "test.subscribe")

        // Give time for notification
        try await Task.sleep(for: .milliseconds(100))

        #expect(value == "external")
    }

    @Test
    func worksWithCodableTypes() async throws {
        struct Settings: Codable, Equatable, Sendable {
            var theme: String
            var fontSize: Int
        }

        let db = try await Database(path: nil)

        @Shared(.keyValueStore("test.codable", store: { db.keyValueStore }))
        var settings: Settings = Settings(theme: "light", fontSize: 14)

        #expect(settings.theme == "light")

        $settings.withLock { $0.theme = "dark" }

        try await Task.sleep(for: .milliseconds(50))

        let stored: Settings? = try db.keyValueStore.get("test.codable")
        #expect(stored?.theme == "dark")
    }

    // MARK: - KeyValueStoreEntityPersistenceKey Tests

    @Test
    func entityKeyLoadsStoredEntity() async throws {
        let db = try await Database(path: nil)

        let preferences = Preferences(
            didShowWelcomeSheet: true,
            errorReportingEnabled: true
        )
        try db.keyValueStore.put(preferences)

        @Shared(.entity(Preferences.key, store: { db.keyValueStore }))
        var loaded: Preferences = Preferences()

        #expect(loaded.didShowWelcomeSheet == true)
        #expect(loaded.errorReportingEnabled == true)
    }

    @Test
    func entityKeySavesEntity() async throws {
        let db = try await Database(path: nil)

        @Shared(.entity(Preferences.key, store: { db.keyValueStore }))
        var preferences: Preferences = Preferences()

        $preferences.withLock { prefs in
            prefs.didShowWelcomeSheet = true
        }

        try await Task.sleep(for: .milliseconds(50))

        let stored: Preferences? = try db.keyValueStore.get(Preferences.key)
        #expect(stored?.didShowWelcomeSheet == true)
    }

    @Test
    func multipleSharedReferencesStaySynced() async throws {
        let db = try await Database(path: nil)

        @Shared(.keyValueStore("test.sync", store: { db.keyValueStore }))
        var value1: String = "initial"

        @Shared(.keyValueStore("test.sync", store: { db.keyValueStore }))
        var value2: String = "initial"

        $value1.withLock { $0 = "updated" }

        try await Task.sleep(for: .milliseconds(100))

        #expect(value2 == "updated")
    }
}

