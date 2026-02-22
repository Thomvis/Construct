//
//  DefaultContent.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels

public struct DefaultContentVersions: Codable, Hashable {
    public let monsters2014: String
    public let spells2014: String
    public let monsters2024: String
    public let spells2024: String

    public init(
        monsters2014: String,
        spells2014: String,
        monsters2024: String,
        spells2024: String
    ) {
        self.monsters2014 = monsters2014
        self.spells2014 = spells2014
        self.monsters2024 = monsters2024
        self.spells2024 = spells2024
    }

    enum CodingKeys: String, CodingKey {
        case monsters2014
        case spells2014
        case monsters2024
        case spells2024

        // Legacy keys
        case monsters
        case spells
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.monsters2014 = try c.decodeIfPresent(String.self, forKey: .monsters2014)
            ?? c.decodeIfPresent(String.self, forKey: .monsters)
            ?? ""
        self.spells2014 = try c.decodeIfPresent(String.self, forKey: .spells2014)
            ?? c.decodeIfPresent(String.self, forKey: .spells)
            ?? ""
        self.monsters2024 = try c.decodeIfPresent(String.self, forKey: .monsters2024) ?? ""
        self.spells2024 = try c.decodeIfPresent(String.self, forKey: .spells2024) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(monsters2014, forKey: .monsters2014)
        try c.encode(spells2014, forKey: .spells2014)
        try c.encode(monsters2024, forKey: .monsters2024)
        try c.encode(spells2024, forKey: .spells2024)
    }
}

public extension DefaultContentVersions {
    static let current = Self(
        monsters2014: "2026.02.21",
        spells2014: "2026.02.21",
        monsters2024: "2026.02.22",
        spells2024: "2026.02.22"
    )
}

public let defaultMonsters2014Path = Bundle.module.path(forResource: "monsters-2014", ofType: "json")!
public let defaultSpells2014Path = Bundle.module.path(forResource: "spells-2014", ofType: "json")!
public let defaultMonsters2024Path = Bundle.module.path(forResource: "monsters-2024", ofType: "json")!
public let defaultSpells2024Path = Bundle.module.path(forResource: "spells-2024", ofType: "json")!

// Backward compatibility aliases for older call sites/tests.
public let defaultMonstersPath = defaultMonsters2014Path
public let defaultSpellsPath = defaultSpells2014Path

public extension CompendiumImportSourceId {
    static let defaultMonsters2014: Self = .init(type: "defaultContent", bookmark: "monsters-2014")
    static let defaultSpells2014: Self = .init(type: "defaultContent", bookmark: "spells-2014")
    static let defaultMonsters2024: Self = .init(type: "defaultContent", bookmark: "monsters-2024")
    static let defaultSpells2024: Self = .init(type: "defaultContent", bookmark: "spells-2024")

    // Backward compatibility aliases.
    static let defaultMonsters: Self = defaultMonsters2014
    static let defaultSpells: Self = defaultSpells2014
}

public extension CompendiumImporter {
    func importDefaultContent(
        monsters2014: Bool = true,
        spells2014: Bool = true,
        monsters2024: Bool = true,
        spells2024: Bool = true
    ) async throws {
        if monsters2014 {
            let task = CompendiumImportTask(
                sourceId: CompendiumImportSourceId.defaultMonsters2014,
                sourceVersion: DefaultContentVersions.current.monsters2014,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultMonsters2014Path).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: CompendiumSourceDocument.srd5_1,
                overwriteExisting: true
            )

            _ = try await run(task)
        }

        if spells2014 {
            let task = CompendiumImportTask(
                sourceId: CompendiumImportSourceId.defaultSpells2014,
                sourceVersion: DefaultContentVersions.current.spells2014,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultSpells2014Path).decode(type: [O5e.Spell].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: CompendiumSourceDocument.srd5_1,
                overwriteExisting: true
            )

            _ = try await run(task)
        }

        if monsters2024 {
            let task = CompendiumImportTask(
                sourceId: CompendiumImportSourceId.defaultMonsters2024,
                sourceVersion: DefaultContentVersions.current.monsters2024,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultMonsters2024Path).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: CompendiumSourceDocument.srd5_2,
                overwriteExisting: true
            )

            _ = try await run(task)
        }

        if spells2024 {
            let task = CompendiumImportTask(
                sourceId: CompendiumImportSourceId.defaultSpells2024,
                sourceVersion: DefaultContentVersions.current.spells2024,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultSpells2024Path).decode(type: [O5e.Spell].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: CompendiumSourceDocument.srd5_2,
                overwriteExisting: true
            )

            _ = try await run(task)
        }
    }
}
