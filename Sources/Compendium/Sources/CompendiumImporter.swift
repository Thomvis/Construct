//
//  CompendiumImporter.swift
//  Construct
//
//  Created by Thomas Visser on 18/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GameModels
import Helpers

public class CompendiumImporter {
    let compendium: Compendium

    public init(compendium: Compendium) {
        self.compendium = compendium
    }

    public func run(_ task: CompendiumImportTask) async throws -> Result {
        var result = Result()
        let job = task.reader.makeJob()
        for await read in try await job.output {
            switch read {
            case .item(let item):
                let entry = apply(CompendiumEntry(item, source: task.source)) {
                    $0.visitParseable()
                }
                do {
                    let willOverwriteExisting = try self.compendium.contains(entry.item.key)

                    if task.overwriteExisting || !willOverwriteExisting {
                        try self.compendium.put(entry)

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

            await Task.yield()
        }
        return result
    }

    public struct Result: Equatable {
        // valid
        public var newItemCount = 0
        public var overwrittenItemCount = 0

        // invalid
        public var invalidItemCount = 0

        public init(newItemCount: Int = 0, overwrittenItemCount: Int = 0, invalidItemCount: Int = 0) {
            self.newItemCount = newItemCount
            self.overwrittenItemCount = overwrittenItemCount
            self.invalidItemCount = invalidItemCount
        }
    }
}

public enum CompendiumImporterError: LocalizedError {
    case reader(CompendiumDataSourceReaderError)
    case database(Error)
    case other(Error)

    public var errorDescription: String? {
        switch self {
        case .reader(let error): return error.localizedDescription
        case .database(let error): return error.localizedDescription
        case .other(let error): return error.localizedDescription
        }
    }
}

public struct CompendiumImportTask {
    public let reader: CompendiumDataSourceReader

    public let overwriteExisting: Bool
    public var source: CompendiumEntry.Source

    public init(reader: CompendiumDataSourceReader, overwriteExisting: Bool = false) {
        self.reader = reader
        self.overwriteExisting = overwriteExisting
        self.source = CompendiumEntry.Source(
            readerName: type(of: reader).name,
            sourceName: type(of: reader.dataSource).name,
            bookmark: reader.dataSource.bookmark,
            displayName: nil
        )
    }
}
