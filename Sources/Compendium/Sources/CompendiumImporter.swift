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

        let job = CompendiumImportJob(
            sourceId: task.sourceId,
            sourceVersion: task.sourceVersion,
            documentId: task.document.id,
            timestamp: Date()
        )

        try compendium.metadata.putJob(job)

        for try await read in try task.reader.items(realmId: CompendiumRealm.core.id) {
            switch read {
            case .item(let item):
                let entry = apply(CompendiumEntry(
                    item,
                    origin: .imported(job.id),
                    document: .init(task.document)
                )) {
                    // post-processing

                    _ = $0.visitParseable()

                    if var combatant = $0.item as? CompendiumCombatant {
                        combatant.stats.makeSkillAndSaveProficienciesRelative()
                        $0.item = combatant
                    }
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
    public let sourceId: CompendiumImportSourceId
    public let sourceVersion: String?

    public let reader: any CompendiumDataSourceReader

    public var document: CompendiumSourceDocument

    public let overwriteExisting: Bool

    public init(
        sourceId: CompendiumImportSourceId,
        sourceVersion: String?,
        reader: any CompendiumDataSourceReader,
        document: CompendiumSourceDocument,
        overwriteExisting: Bool
    ) {
        self.sourceId = sourceId
        self.sourceVersion = sourceVersion
        self.reader = reader
        self.document = document
        self.overwriteExisting = overwriteExisting
    }
}
