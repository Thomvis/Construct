//
//  CompendiumFetchRequest.swift
//  
//
//  Created by Thomas Visser on 18/01/2025.
//  Copyright © 2025 Thomas Visser. All rights reserved.
//

import Foundation

public struct CompendiumFetchRequest: Equatable {
    public var search: String?
    public var filters: CompendiumFilters?
    public var order: Order?
    public var range: Range<Int>?
    
    public init(
        search: String? = nil,
        filters: CompendiumFilters? = nil,
        order: Order? = nil,
        range: Range<Int>? = nil
    ) {
        self.search = search
        self.filters = filters
        self.order = order
        self.range = range
    }
} 
