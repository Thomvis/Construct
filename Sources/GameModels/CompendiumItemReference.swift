//
//  CompendiumItemReference.swift
//  
//
//  Created by Thomas Visser on 19/08/2022.
//

import Foundation

public struct CompendiumItemReference: Codable, Hashable {
    public var itemTitle: String
    public let itemKey: CompendiumItemKey

    public init(itemTitle: String, itemKey: CompendiumItemKey) {
        self.itemTitle = itemTitle
        self.itemKey = itemKey
    }
}
