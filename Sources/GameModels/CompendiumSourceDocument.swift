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

    public let id: Id
    public let displayName: String

    public let realmId: CompendiumRealm.Id

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
}
