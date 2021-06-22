//
//  Database.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB

class Database {

    let queue: DatabaseQueue

    public let keyValueStore: KeyValueStore

    // If path is nil, an in-memory database is created
    init(path: String?, importDefaultContent: Bool = true) throws {
        self.queue = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue(configuration: Configuration())
        self.keyValueStore = KeyValueStore(queue)

        print("Created/opened database at path: \(path ?? "in-memory")")

        try migrator(self.queue, importDefaultContent: importDefaultContent).migrate(self.queue)
    }

}
