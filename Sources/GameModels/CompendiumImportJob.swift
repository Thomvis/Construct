//
//  CompendiumImportJob.swift
//  Construct
//
//  Created by Thomas Visser on 11/08/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged
import CryptoKit

/// Represents a file, url or other source of compendium items
public struct CompendiumImportSourceId: Hashable, Codable, RawRepresentable {
    public let type: String
    public let bookmark: String

    public init(type: String, bookmark: String) {
        self.type = type
        self.bookmark = bookmark
    }

    public init?(rawValue: String) {
        let components = rawValue.split(separator: "::")
        guard components.count == 2 else { return nil }

        self.type = String(components[0])
        self.bookmark = String(components[1])
    }

    public var rawValue: String {
        "\(type)::\(bookmark)"
    }
}

public struct CompendiumImportJob: Hashable, Codable {
    public typealias Id = Tagged<Self, String>

    public let sourceId: CompendiumImportSourceId
    public let sourceVersion: String?
    public let documentId: CompendiumSourceDocument.Id

    public var timestamp: Date
    public let uuid: UUID

    public var id: Id {
        Self.jobId(sourceId: sourceId, uuid: uuid)
    }

    public init(sourceId: CompendiumImportSourceId, sourceVersion: String?, documentId: CompendiumSourceDocument.Id, timestamp: Date = Date(), uuid: UUID = UUID()) {
        self.sourceId = sourceId
        self.sourceVersion = sourceVersion
        self.documentId = documentId
        self.timestamp = timestamp
        self.uuid = uuid
    }

    public static func jobId(sourceId: CompendiumImportSourceId, uuid: UUID) -> CompendiumImportJob.Id {
        return Tagged(rawValue: jobIdPrefix(sourceId: sourceId) + uuid.uuidString)
    }

    /// Returns a prefix of a hash of the source id. Intended to effectively bucket jobs based
    /// on their source. Collisions are possible (that's why the uuid is added to the id)
    public static func jobIdPrefix(sourceId: CompendiumImportSourceId) -> String {
        let digest = SHA256.hash(data: sourceId.rawValue.data(using: .utf8)!)
        return String(digest.compactMap { String(format: "%02x", $0) }.joined().prefix(5))
    }
}
