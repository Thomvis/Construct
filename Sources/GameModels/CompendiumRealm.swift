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
        id: .init("core"),
        displayName: "Core 5e"
    )

    static let homebrew = CompendiumRealm(
        id: .init("homebrew"),
        displayName: "Homebrew"
    )
}
