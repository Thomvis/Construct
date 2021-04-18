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

    func run(_ task: CompendiumImportTask) -> AnyPublisher<Result, CompendiumImporterError> {
        task.reader.read().output
            .mapError { CompendiumImporterError.reader($0) }
            .tryScan(Result()) { res, read in
                var result = res
                switch read {
                case .item(let item):
                    let entry = CompendiumEntry(item, source: task.source)
                    do {
                        let willOverwriteExisting = try self.compendium.database.keyValueStore.contains(entry.key, in: task.db)

                        if task.overwriteExisting || !willOverwriteExisting {
                            try self.compendium.put(entry, in: task.db)

                            if willOverwriteExisting {
                                result.overwrittenItemCount += 1
                            } else {
                                result.newItemCount += 1
                            }
                        }
                    } catch {
                        throw CompendiumImporterError.database(error)
                    }
                case .invalidItem:
                    result.invalidItemCount += 1
                }
                return result
            }
            .mapError {
                guard let error = $0 as? CompendiumImporterError else { return CompendiumImporterError.other($0) }
                return error
            }
            .last()
            .eraseToAnyPublisher()
    }

    struct Result: Equatable {
        // valid
        var newItemCount = 0
        var overwrittenItemCount = 0

        // invalid
        var invalidItemCount = 0
    }
}

enum CompendiumImporterError: Swift.Error {
    case reader(CompendiumDataSourceReaderError)
    case database(Error)
    case other(Error)
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
