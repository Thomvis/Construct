//
//  File.swift
//  
//
//  Created by Thomas Visser on 08/10/2022.
//

import Foundation

public enum InitialDatabase {
    public static let path = Bundle.module.path(forResource: "initial", ofType: "sqlite")
}

