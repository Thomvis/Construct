//
//  Database.swift
//  Construct
//
//  Created by Thomas Visser on 02/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import Compendium
import Combine

public class Database {

    let queue: DatabaseQueue

    public let keyValueStore: KeyValueStore
    public let parseableManager: ParseableKeyValueRecordManager

    // If path is nil, an in-memory database is created
    public init(path: String?, importDefaultContent: Bool = true) throws {
        self.queue = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue(configuration: Configuration())
        self.keyValueStore = KeyValueStore(queue)
        self.parseableManager = ParseableKeyValueRecordManager(queue)

        print("Created/opened database at path: \(path ?? "in-memory")")

        let migrator = try migrator(self.queue, importDefaultContent: importDefaultContent)
        try migrator.migrate(self.queue)

        #warning("migrate if fixtures versions changed or (for backwardcompat if certain migrations were triggered)")
    }

    func importDefaultContent() throws {
        let compendium = DatabaseCompendium(database: self, fallback: .empty)

        // Monsters
        if let monstersPath = Bundle.main.path(forResource: "monsters", ofType: "json") {
            var task = CompendiumImportTask(reader: Open5eMonsterDataSourceReader(dataSource: FileDataSource(path: monstersPath)), overwriteExisting: true)
            task.source.displayName = "Open Game Content (SRD 5.1)"
            var cancellables: [AnyCancellable] = []

            CompendiumImporter(compendium: compendium).run(task).sink(receiveCompletion: { _ in
                cancellables.removeAll()
            }, receiveValue: { _ in }).store(in: &cancellables)
        }

        // Spells
        if let spellsPath = Bundle.main.path(forResource: "spells", ofType: "json") {
            var task = CompendiumImportTask(reader: Open5eSpellDataSourceReader(dataSource: FileDataSource(path: spellsPath)), overwriteExisting: true)
            task.source.displayName = "Open Game Content (SRD 5.1)"
            var cancellables: [AnyCancellable] = []

            CompendiumImporter(compendium: compendium).run(task).sink(receiveCompletion: { _ in
                cancellables.removeAll()
            }, receiveValue: { _ in }).store(in: &cancellables)
        }
    }

}
