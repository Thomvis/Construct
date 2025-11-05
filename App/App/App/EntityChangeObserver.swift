//
//  EntityChangeObserver.swift
//  Construct
//
//  Created by Thomas Visser on 14/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import ComposableArchitecture
import Persistence

protocol HavingEntities {
    var entities: [any KeyValueStoreEntity] { get }
}

extension AppState: HavingEntities {
    var entities: [any KeyValueStoreEntity] {
        return [
            navigation?.tabState?.entities,
            navigation?.columnState?.entities
        ].compactMap { $0 }.flatMap { $0 }
    }
}

extension TabNavigationViewState: HavingEntities {
    var entities: [any KeyValueStoreEntity] {
        return campaignBrowser.entities
    }
}

extension ColumnNavigationViewState: HavingEntities {
    var entities: [any KeyValueStoreEntity] {
        return (campaignBrowse.nextScreen?.entities ?? [])
    }
}

extension CampaignBrowseViewFeature.State: HavingEntities {
    var entities: [any KeyValueStoreEntity] {
        return (nextScreen?.entities ?? []) + (detailScreen?.entities ?? [])
    }
}

extension CampaignBrowseViewFeature.State.NextScreen: HavingEntities {
    var entities: [any KeyValueStoreEntity] {
        switch self {
        case .campaignBrowse(let state): return state.entities
        case .encounter(let state): return state.entities
        }
    }
}

extension EncounterDetailFeature.State: HavingEntities {
    var entities: [any KeyValueStoreEntity] {
        return [building, running.map { $0 as any KeyValueStoreEntity }].compactMap { $0 }
    }
}

extension DatabaseKeyValueStore {


    // Returns a middleware that saves changed entities to the db
    // fixme: naive implementation, might become very slow
    func entityChangeObserver<Environment, State, Action>(initialState: State, reducer: AnyReducer<State, Action, Environment>) -> AnyReducer<State, Action, Environment> where State: HavingEntities {


        var cache: [String: Data] = [:]

        for e in initialState.entities {
            if let encoded = try? Self.encoder.encode(e) {
                cache[e.rawKey] = encoded
            }
        }

        return AnyReducer { state, action, environment in
            // run the wrapped reducer
            let effects = reducer.callAsFunction(&state, action, environment)

            // fixme: use effects for saving?
            state.entities.compactMap { e -> (any KeyValueStoreEntity, Data)? in
                guard let encoded = try? Self.encoder.encode(e) else { return nil }

                if cache[e.rawKey] == nil {
                    // new entity
                    return (e, encoded)
                } else if let encoded = try? Self.encoder.encode(e), encoded != cache[e.rawKey] {
                    // entity changed
                    return (e, encoded)
                }
                return nil
            }.forEach { entityAndData in
                do {
                    try self.put(entityAndData.0)
                    cache[entityAndData.0.rawKey] = entityAndData.1
                } catch {
                    print("Failed saving changed entity with key \(entityAndData.0.rawKey). Error: \(error)")
                }
            }
            return effects
        }
    }
}
