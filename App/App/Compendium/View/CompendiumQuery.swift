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

extension CompendiumIndexState {

    struct Query: Equatable {
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
    }
}
