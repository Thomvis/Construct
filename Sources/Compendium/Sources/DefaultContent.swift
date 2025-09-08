//
//  DefaultContent.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels
import Tagged

public struct DefaultContentVersions: Codable, Hashable {
    public let monsters: String
    public let spells: String
}

public extension DefaultContentVersions {
    static let current = Self(
        monsters: "2021.03.19a",
        spells: "2020.09.26"
    )
}

public let defaultMonstersPath = Bundle.module.path(forResource: "monsters", ofType: "json")!
public let defaultSpellsPath = Bundle.module.path(forResource: "spells", ofType: "json")!

public extension CompendiumImportSourceId {
    static let defaultMonsters: Self = .init(type: "defaultContent", bookmark: "monsters")
    static let defaultSpells: Self = .init(type: "defaultContent", bookmark: "spells")
}

public extension CompendiumImporter {
    func importDefaultContent(monsters: Bool = true, spells: Bool = true) async throws {
        // Monsters
        if monsters {
            let task = CompendiumImportTask(
                sourceId: CompendiumImportSourceId.defaultMonsters,
                sourceVersion: DefaultContentVersions.current.monsters,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultMonstersPath).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: CompendiumSourceDocument.srd5_1,
                overwriteExisting: true
            )

            _ = try await run(task)
        }

        // Spells
        if spells {
            let task = CompendiumImportTask(
                sourceId: CompendiumImportSourceId.defaultSpells,
                sourceVersion: DefaultContentVersions.current.spells,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultSpellsPath).decode(type: [O5e.Spell].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: CompendiumSourceDocument.srd5_1,
                overwriteExisting: true
            )

            _ = try await run(task)
        }
    }
}
