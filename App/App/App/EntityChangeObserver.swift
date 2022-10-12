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
    var entities: [AnyKeyValueStoreEntity] { get }
}

extension AppState: HavingEntities {
    var entities: [AnyKeyValueStoreEntity] {
        return [
            navigation?.tabState?.entities,
            navigation?.columnState?.entities
        ].compactMap { $0 }.flatMap { $0 }
    }
}

extension TabNavigationViewState: HavingEntities {
    var entities: [AnyKeyValueStoreEntity] {
        return campaignBrowser.entities
    }
}

extension ColumnNavigationViewState: HavingEntities {
    var entities: [AnyKeyValueStoreEntity] {
        return (campaignBrowse.nextScreen?.entities ?? [])
    }
}

extension CampaignBrowseViewState: HavingEntities {
    var entities: [AnyKeyValueStoreEntity] {
        return (nextScreen?.entities ?? []) + (detailScreen?.entities ?? [])
    }
}

extension CampaignBrowseViewState.NextScreen: HavingEntities {
    var entities: [AnyKeyValueStoreEntity] {
        switch self {
        case .campaignBrowse(let state): return state.entities
        case .encounter(let state): return state.entities
        }
    }
}

extension EncounterDetailViewState: HavingEntities {
    var entities: [AnyKeyValueStoreEntity] {
        return [AnyKeyValueStoreEntity(building), AnyKeyValueStoreEntity(running)].compactMap { $0 }
    }
}

extension KeyValueStore {


    // Returns a middleware that saves changed entities to the db
    // fixme: naive implementation, might become very slow
    func entityChangeObserver<Environment, State, Action>(initialState: State, reducer: Reducer<State, Action, Environment>) -> Reducer<State, Action, Environment> where State: HavingEntities {

        var cache: [String: Data] = [:]

        for e in initialState.entities {
            if let encoded = try? Self.encoder.encode(e) {
                cache[e.key] = encoded
            }
        }

        return Reducer { state, action, environment in
            // run the wrapped reducer
            let effects = reducer.callAsFunction(&state, action, environment)

            // fixme: use effects for saving?
            state.entities.compactMap { e -> (AnyKeyValueStoreEntity, Data)? in
                guard let encoded = try? Self.encoder.encode(e) else { return nil }

                if cache[e.key] == nil {
                    // new entity
                    return (e, encoded)
                } else if let encoded = try? Self.encoder.encode(e), encoded != cache[e.key] {
                    // entity changed
                    return (e, encoded)
                }
                return nil
            }.forEach { entityAndData in
                do {
                    try self.put(entityAndData.0)
                    cache[entityAndData.0.key] = entityAndData.1
                } catch {
                    print("Failed saving changed entity with key \(entityAndData.0.key). Error: \(error)")
                }
            }
            return effects
        }
    }
}
