//
//  CompendiumKeyValueEntities.swift
//  
//
//  Created by Thomas Visser on 08/10/2022.
//

import Foundation
import Compendium
import Tagged

/// DefaultContentVersions is a singleton entity
extension DefaultContentVersions: KeyValueStoreEntity {
    public static let keyPrefix: String = "Construct::DefaultContentVersions"
    public static let key: Key = Key(id: "")

    public var key: Key {
        Self.key
    }
}
