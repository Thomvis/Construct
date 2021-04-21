//
//  CompendiumItemGroup.swift
//  Construct
//
//  Created by Thomas Visser on 04/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

struct CompendiumItemGroup: CompendiumItem, Equatable {
    let id: Id
    var title: String

    var members: [CompendiumItemReference]

    func contains(_ character: Character) -> Bool {
        members.first(where: { $0.itemKey == character.key }) != nil
    }

    /// Updates the cached titles for group members and removes members that no longer exist
    /// Returns true if anything changed
    mutating func updateMemberReferences(with characters: [Character]) -> Bool {
        var didChange = false
        for (idx, member) in members.enumerated().reversed() {
            if let character = characters.first(where: { $0.key == member.itemKey }) {
                if character.title != member.itemTitle {
                    members[idx].itemTitle = character.title
                    didChange = true
                }
            } else {
                // member character no longer exists
                members.remove(at: idx)
                didChange = true
            }
        }
        return didChange
    }

    var realm: CompendiumItemKey.Realm { .homebrew }
    var key: CompendiumItemKey {
        CompendiumItemKey(type: .group, realm: realm, identifier: id.rawValue.uuidString)
    }

    typealias Id = Tagged<CompendiumItemGroup, UUID>
}

struct CompendiumItemReference: Codable, Hashable {
    var itemTitle: String
    let itemKey: CompendiumItemKey
}

extension CompendiumItemGroup {
    static let nullInstance = CompendiumItemGroup(id: UUID().tagged(), title: "", members: [])
}
