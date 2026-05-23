//
//  CompendiumRealm.swift
//  
//
//  Created by Thomas Visser on 14/07/2023.
//

import Foundation
import Tagged

public struct CompendiumRealm: Hashable, Codable {
    public typealias Id = Tagged<Self, String>

    public let id: Id
    public let displayName: String

    public init(id: Id, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public extension CompendiumRealm {
    static let core = CompendiumRealm(
        id: .init("core5e"),
        displayName: "Core 5e"
    )

    static let core2024 = CompendiumRealm(
        id: .init("core5.5e"),
        displayName: "Core 5.5e"
    )

    static let homebrew = CompendiumRealm(
        id: .init("homebrew"),
        displayName: "Homebrew"
    )

    private static var defaultRealms: [CompendiumRealm] {
        [.core, .core2024, .homebrew]
    }

    static func isDefaultRealm(id: CompendiumRealm.Id) -> Bool {
        defaultRealms.contains(where: { $0.id == id })
    }

    var isDefaultRealm: Bool {
        Self.isDefaultRealm(id: id)
    }
}
