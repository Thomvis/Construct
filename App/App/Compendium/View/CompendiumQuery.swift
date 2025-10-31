//
//  CompendiumQuery.swift
//  Construct
//
//  Created by Thomas Visser on 02/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers
import GameModels
import Compendium
import ComposableArchitecture

extension CompendiumIndexFeature {

    struct Query: Reducer {
        struct State: Equatable {
            var text: String?
            var filters: CompendiumFilters?
            var order: Order

            func fetchRequest(range: Range<Int>?) -> CompendiumFetchRequest {
                CompendiumFetchRequest(
                    search: text,
                    filters: filters,
                    order: order,
                    range: range
                )
            }

            static let nullInstance = Self(text: nil, filters: nil, order: .title)
        }

        enum Action: Equatable {
            case onTextDidChange(String?)
            case onTypeFilterDidChange([CompendiumItemType]?)
            case onFiltersDidChange(CompendiumFilters)
        }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .onTextDidChange(let t):
                state.text = t
            case .onTypeFilterDidChange(let types):
                if state.filters != nil {
                    state.filters?.types = types
                } else if types != nil {
                    state.filters = CompendiumFilters(types: types)
                }
                state.order = .default(types ?? CompendiumItemType.allCases)
            case .onFiltersDidChange(let f):
                if state.filters?.types != f.types {
                    state.order = .default(f.types ?? CompendiumItemType.allCases)
                }
                state.filters = f
            }
            return .none
        }
    }
}

//private struct QueryReducer: Reducer {
//    func reduce(into state: inout CompendiumIndexFeature.State.Query, action: CompendiumIndexQueryAction) -> Effect<Action> {
//
//    }
//}
//
//extension CompendiumIndexFeature.State.Query {
//    static let nullInstance = CompendiumIndexFeature.State.Query(text: nil, filters: nil, order: .title)
//}

