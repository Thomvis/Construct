//
//  CompendiumItemGroup.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 04/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation

struct CompendiumItemGroup: CompendiumItem, Equatable {
    let id: UUID
    var title: String

    var members: [CompendiumItemReference]

    func contains(_ character: Character) -> Bool {
        members.first(where: { $0.itemKey == character.key }) != nil
    }

    var realm: CompendiumItemKey.Realm { .homebrew }
    var key: CompendiumItemKey {
        CompendiumItemKey(type: .group, realm: realm, identifier: id.uuidString)
    }
}

struct CompendiumItemReference: Codable, Hashable {
    var itemTitle: String
    let itemKey: CompendiumItemKey
}

extension CompendiumItemGroup {
    static let nullInstance = CompendiumItemGroup(id: UUID(), title: "", members: [])
}
