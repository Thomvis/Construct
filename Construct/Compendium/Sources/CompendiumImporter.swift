//
//  CompendiumImporter.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 18/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GRDB

class CompendiumImporter {
    let compendium: Compendium

    init(compendium: Compendium) {
        self.compendium = compendium
    }

    func run(_ task: CompendiumImportTask) -> some Publisher {
        let job = task.reader.read()

        return job.items.handleEvents(receiveOutput: { item in
            let entry = CompendiumEntry(item, source: task.source)
            do {
                if try task.overwriteExisting || !self.compendium.database.keyValueStore.contains(entry.key, in: task.db) {
                    try self.compendium.put(entry, in: task.db)
                }
            } catch {
                print(error)
            }
        }).ignoreOutput()
    }
}

struct CompendiumImportTask {
    let reader: CompendiumDataSourceReader

    let overwriteExisting: Bool
    var source: CompendiumEntry.Source

    let db: GRDB.Database?

    init(reader: CompendiumDataSourceReader, overwriteExisting: Bool = false, db: GRDB.Database? = nil) {
        self.reader = reader
        self.overwriteExisting = overwriteExisting
        self.source = CompendiumEntry.Source(
            readerName: type(of: reader).name,
            sourceName: type(of: reader.dataSource).name,
            bookmark: reader.dataSource.bookmark,
            displayName: nil
        )
        self.db = db
    }
}
