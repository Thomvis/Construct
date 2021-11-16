//
//  Preferences.swift
//  Construct
//
//  Created by Thomas Visser on 02/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

struct Preferences: Codable, Equatable {
    var didShowWelcomeSheet = false
}

extension Preferences: KeyValueStoreEntity {
    static let keyPrefix: KeyPrefix = .preferences
    static let key = keyPrefix.rawValue

    var key: String {
        Self.key
    }
}
