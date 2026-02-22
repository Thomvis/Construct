//
//  CompendiumSourceDocument.swift
//  
//
//  Created by Thomas Visser on 18/06/2023.
//

import Foundation
import Tagged

public struct CompendiumSourceDocument: Hashable, Codable, Identifiable {
    public typealias Id = Tagged<Self, String>

    public var id: Id
    public var displayName: String

    public var realmId: CompendiumRealm.Id

    public init(id: Id, displayName: String, realmId: CompendiumRealm.Id) {
        self.id = id
        self.displayName = displayName
        self.realmId = realmId
    }
}

public extension CompendiumSourceDocument {
    static let srd5_1 = CompendiumSourceDocument(
        id: "srd",
        displayName: "SRD 5.1",
        realmId: CompendiumRealm.core.id
    )

    static let srd5_2 = CompendiumSourceDocument(
        id: "srd52",
        displayName: "SRD 5.2",
        realmId: CompendiumRealm.core2024.id
    )

    static let unspecifiedCore = CompendiumSourceDocument(
        id: "core",
        displayName: "Unspecified",
        realmId: CompendiumRealm.core.id
    )

    static let homebrew = CompendiumSourceDocument(
        id: "homebrew",
        displayName: "Homebrew",
        realmId: CompendiumRealm.homebrew.id
    )

    private static var defaultDocuments: [CompendiumSourceDocument] {
        [.srd5_1, .srd5_2, .unspecifiedCore, .homebrew]
    }

    static func isDefaultDocument(id: CompendiumSourceDocument.Id) -> Bool {
        defaultDocuments.contains(where: { $0.id == id })
    }

    var isDefaultDocument: Bool {
        Self.isDefaultDocument(id: id)
    }
}
