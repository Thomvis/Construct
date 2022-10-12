//
//  DefaultContent.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation

public struct DefaultContentVersions: Codable, Hashable {
    public let monsters: String
    public let spells: String
}

public extension DefaultContentVersions {
    static let current = Self(
        monsters: "2021.03.19",
        spells: "2020.09.26"
    )
}

public let defaultMonstersPath = Bundle.main.path(forResource: "monsters", ofType: "json")
public let defaultSpellsPath = Bundle.main.path(forResource: "spells", ofType: "json")
