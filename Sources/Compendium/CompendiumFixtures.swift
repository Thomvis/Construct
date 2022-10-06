//
//  CompendiumFixtures.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation

public struct CompendiumFixtures: Codable, Hashable {
    public let monstersVersion: String
    public let spellsVersion: String
}

extension CompendiumFixtures {
    static let current = CompendiumFixtures(
        monstersVersion: "2021.03.19",
        spellsVersion: "2020.09.26"
    )
}
