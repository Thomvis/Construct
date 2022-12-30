//
//  Environment.swift
//  
//
//  Created by Thomas Visser on 20/12/2022.
//

import Foundation

public protocol EnvironmentWithDatabase {
    var database: Database { get }
}
