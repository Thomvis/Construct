//
//  PreferencesClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import GameModels
import ComposableArchitecture

public struct PreferencesClient {
    public var get: () -> Preferences
    public var update: ((inout Preferences) -> Void) throws -> Void
    
    public init(
        get: @escaping () -> Preferences,
        update: @escaping ((inout Preferences) -> Void) throws -> Void
    ) {
        self.get = get
        self.update = update
    }
}

extension PreferencesClient: DependencyKey {
    public static var liveValue: PreferencesClient {
        @Dependency(\.database) var database
        
        return PreferencesClient(
            get: {
                (try? database.keyValueStore.get(Preferences.key)) ?? Preferences()
            },
            update: { f in
                var p = (try? database.keyValueStore.get(Preferences.key)) ?? Preferences()
                f(&p)
                try database.keyValueStore.put(p)
            }
        )
    }
}

public extension DependencyValues {
    var preferences: PreferencesClient {
        get { self[PreferencesClient.self] }
        set { self[PreferencesClient.self] = newValue }
    }
}

