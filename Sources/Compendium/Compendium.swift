//
//  Compendium.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels
import Helpers
import Combine

public protocol Compendium {
    func get(_ key: CompendiumItemKey) throws -> CompendiumEntry?
    func get(_ key: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry?
    func put(_ entry: CompendiumEntry) throws
    func contains(_ key: CompendiumItemKey) throws -> Bool
    func fetchAll(query: String?, types: [CompendiumItemType]?) throws -> [CompendiumEntry]
    func fetchAll(query: String?) throws -> [CompendiumEntry]
    func resolve(annotation: CompendiumItemReferenceTextAnnotation) -> ReferenceResolveResult
}

public enum ReferenceResolveResult {
    case `internal`(CompendiumItemReference)
    case external(URL)
    case notFound
}

public extension Compendium {
    func importDefaultContent(monsters: Bool = true, spells: Bool = true) async throws {
        // Monsters
        if monsters {
            var task = CompendiumImportTask(reader: Open5eMonsterDataSourceReader(dataSource: FileDataSource(path: defaultMonstersPath)), overwriteExisting: true)
            task.source.displayName = "Open Game Content (SRD 5.1)"

            _ = try await CompendiumImporter(compendium: self).run(task)
        }

        // Spells
        if spells {
            var task = CompendiumImportTask(reader: Open5eSpellDataSourceReader(dataSource: FileDataSource(path: defaultSpellsPath)), overwriteExisting: true)
            task.source.displayName = "Open Game Content (SRD 5.1)"

            _ = try await CompendiumImporter(compendium: self).run(task)
        }
    }
}
