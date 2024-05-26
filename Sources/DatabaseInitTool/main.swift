//
//  main.swift
//  
//
//  Created by Thomas Visser on 06/10/2022.
//

import Foundation
import Persistence

let path = "Sources/TestSupport/Resources/initial.sqlite"
if FileManager.default.fileExists(atPath: path) {
    try FileManager.default.removeItem(atPath: path)
}

let db = try await Database(path: path, importDefaultContent: true)
try db.close()
