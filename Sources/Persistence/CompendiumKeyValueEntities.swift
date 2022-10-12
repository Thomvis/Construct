//
//  CompendiumKeyValueEntities.swift
//  
//
//  Created by Thomas Visser on 08/10/2022.
//

import Foundation
import Compendium

extension DefaultContentVersions: KeyValueStoreEntity {
    public static let keyPrefix: KeyPrefix = .defaultContentVersions
    public static let key = keyPrefix.rawValue

    public var key: String {
        Self.key
    }
}
