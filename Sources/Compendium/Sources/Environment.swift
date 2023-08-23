//
//  Environment.swift
//  
//
//  Created by Thomas Visser on 22/08/2023.
//

import Foundation

public protocol EnvironmentWithCompendium {
    var compendium: Compendium { get }
}

public protocol EnvironmentWithCompendiumMetadata {
    var compendiumMetadata: CompendiumMetadata { get }
}
