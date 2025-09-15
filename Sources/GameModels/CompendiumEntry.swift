//
//  CompendiumEntry.swift
//  Construct
//
//  Created by Thomas Visser on 03/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

// An entry in the compendium. Contains the actual item with some metadata
// Suitable for persistence
public struct CompendiumEntry: Equatable {
    @EqCompare public var item: CompendiumItem
    public let itemType: CompendiumItemType

    public var origin: Origin
    public var document: CompendiumSourceDocumentReference

    @CodableIgnored
    public var error: Error?

    public init(_ item: CompendiumItem, origin: Origin, document: CompendiumSourceDocumentReference) {
        _item = EqCompare(wrappedValue: item, compare: { $0.isEqual(to: $1) })
        self.itemType = item.key.type
        self.origin = origin
        self.document = document
    }

    public enum Origin: Equatable, Codable {
        case created(CompendiumItemReference?)
        case imported(CompendiumImportJob.Id?)
    }

    public struct CompendiumSourceDocumentReference: Equatable, Codable {
        public var id: CompendiumSourceDocument.Id
        public var displayName: String

        public init(id: CompendiumSourceDocument.Id, displayName: String) {
            self.id = id
            self.displayName = displayName
        }

        public init(_ document: CompendiumSourceDocument) {
            self.init(id: document.id, displayName: document.displayName)
        }
    }

    public struct Error: Equatable {
        let errorDump: String
        let data: Data

        public init(errorDump: String, data: Data) {
            self.errorDump = errorDump
            self.data = data
        }
    }

}

extension CompendiumEntry: Codable {
    public enum CodingKeys: CodingKey {
        case item, itemType, origin, document
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let itemType = try container.decode(CompendiumItemType.self, forKey: .itemType)

        self.init(
            try itemType.decodeItem(from: container, key: .item),
            origin: try container.decode(Origin.self, forKey: .origin),
            document: try container.decode(CompendiumSourceDocumentReference.self, forKey: .document)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item, forKey: .item)
        try container.encode(itemType, forKey: .itemType)
        try container.encode(origin, forKey: .origin)
        try container.encode(document, forKey: .document)
    }
}

extension CompendiumEntry {
    public static let nullInstance = CompendiumEntry(
        Monster(realm: .init(CompendiumRealm.core.id), stats: StatBlock.default, challengeRating: .init(integer: 1)),
        origin: .created(nil),
        document: CompendiumSourceDocumentReference(id: CompendiumSourceDocument.Id(rawValue: ""), displayName: "")
    )
}

extension CompendiumEntry {
    public var attribution: AttributedString? {
        var result = AttributedString("")
        if case .created(let ref?) = origin {
            result.append(AttributedString("Based on “"))
            result.append(ref.attributedTitle)
            result.append(AttributedString("” - "))
        }

        result.append(AttributedString("\(document.displayName) (\(item.realm.value.rawValue.uppercased()))"))
        return result
    }
}
