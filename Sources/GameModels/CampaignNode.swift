//
//  CampaignNode.swift
//  Construct
//
//  Created by Thomas Visser on 10/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

public struct CampaignNode: Equatable, Codable {
    public let id: Id
    public var title: String
    public let contents: Contents?
    public let special: Special?

    public var parentKeyPrefix: String?

    public init(id: Id, title: String, contents: Contents?, special: Special?, parentKeyPrefix: String? = nil) {
        self.id = id
        self.title = title
        self.contents = contents
        self.special = special
        self.parentKeyPrefix = parentKeyPrefix
    }

    public typealias Id = Tagged<CampaignNode, UUID>

    public struct Contents: Equatable, Codable {
        public let key: String
        public let type: ContentType

        public init(key: String, type: ContentType) {
            self.key = key
            self.type = type
        }

        public enum ContentType: String, Codable {
            case encounter
            case other // needed to work around a bug in SwiftUI that causes infinite memory to be used
        }
    }

    public enum Special: String, Codable {
        case root
        case scratchPadEncounter
        case trash
    }
}
