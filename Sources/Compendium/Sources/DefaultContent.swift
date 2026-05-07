//
//  DefaultContent.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels

public struct DefaultContentSelection: Codable, Hashable, Sendable {
    public var include2014: Bool
    public var include2024: Bool

    public init(include2014: Bool, include2024: Bool) {
        self.include2014 = include2014
        self.include2024 = include2024
    }

    public var hasAnySelection: Bool {
        include2014 || include2024
    }

    public static let none = Self(include2014: false, include2024: false)
    public static let rules2014Only = Self(include2014: true, include2024: false)
    public static let rules2024Only = Self(include2014: false, include2024: true)
    public static let both = Self(include2014: true, include2024: true)
}

public struct DefaultContentImportComponents: Hashable, Sendable {
    public var monsters2014: Bool
    public var spells2014: Bool
    public var monsters2024: Bool
    public var spells2024: Bool

    public init(
        monsters2014: Bool,
        spells2014: Bool,
        monsters2024: Bool,
        spells2024: Bool
    ) {
        self.monsters2014 = monsters2014
        self.spells2014 = spells2014
        self.monsters2024 = monsters2024
        self.spells2024 = spells2024
    }

    public var needsAnyImport: Bool {
        monsters2014 || spells2014 || monsters2024 || spells2024
    }

    public static let none = Self(
        monsters2014: false,
        spells2014: false,
        monsters2024: false,
        spells2024: false
    )
}

public struct DefaultContentVersions: Codable, Hashable {
    public let monsters2014: String?
    public let spells2014: String?
    public let monsters2024: String?
    public let spells2024: String?

    public init(
        monsters2014: String? = nil,
        spells2014: String? = nil,
        monsters2024: String? = nil,
        spells2024: String? = nil
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

        self.monsters2014 = Self.normalizedVersion(
            try c.decodeIfPresent(String.self, forKey: .monsters2014)
                ?? c.decodeIfPresent(String.self, forKey: .monsters)
        )
        self.spells2014 = Self.normalizedVersion(
            try c.decodeIfPresent(String.self, forKey: .spells2014)
                ?? c.decodeIfPresent(String.self, forKey: .spells)
        )
        self.monsters2024 = Self.normalizedVersion(
            try c.decodeIfPresent(String.self, forKey: .monsters2024)
        )
        self.spells2024 = Self.normalizedVersion(
            try c.decodeIfPresent(String.self, forKey: .spells2024)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(monsters2014, forKey: .monsters2014)
        try c.encodeIfPresent(spells2014, forKey: .spells2014)
        try c.encodeIfPresent(monsters2024, forKey: .monsters2024)
        try c.encodeIfPresent(spells2024, forKey: .spells2024)
    }

    private static func normalizedVersion(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

public extension DefaultContentVersions {
    static let currentMonsters2014 = "2026.02.21"
    static let currentSpells2014 = "2026.02.21"
    static let currentMonsters2024 = "2026.02.22"
    static let currentSpells2024 = "2026.02.22"

    static let current = Self(
        monsters2014: currentMonsters2014,
        spells2014: currentSpells2014,
        monsters2024: currentMonsters2024,
        spells2024: currentSpells2024
    )

    static let empty = Self()

    static func componentsNeedingImport(
        selection: DefaultContentSelection,
        installed: DefaultContentVersions?
    ) -> DefaultContentImportComponents {
        guard selection.hasAnySelection else { return .none }

        let installed = installed ?? .empty
        return DefaultContentImportComponents(
            monsters2014: selection.include2014 && installed.monsters2014 != currentMonsters2014,
            spells2014: selection.include2014 && installed.spells2014 != currentSpells2014,
            monsters2024: selection.include2024 && installed.monsters2024 != currentMonsters2024,
            spells2024: selection.include2024 && installed.spells2024 != currentSpells2024
        )
    }

    var needs2014Update: Bool {
        monsters2014 != Self.currentMonsters2014 || spells2014 != Self.currentSpells2014
    }

    var needs2024Update: Bool {
        monsters2024 != Self.currentMonsters2024 || spells2024 != Self.currentSpells2024
    }

    func applyingCurrentVersions(for importedComponents: DefaultContentImportComponents) -> Self {
        Self(
            monsters2014: importedComponents.monsters2014 ? Self.currentMonsters2014 : monsters2014,
            spells2014: importedComponents.spells2014 ? Self.currentSpells2014 : spells2014,
            monsters2024: importedComponents.monsters2024 ? Self.currentMonsters2024 : monsters2024,
            spells2024: importedComponents.spells2024 ? Self.currentSpells2024 : spells2024
        )
    }
}

public let defaultMonsters2014Path = Bundle.module.path(forResource: "monsters-2014", ofType: "json")!
public let defaultSpells2014Path = Bundle.module.path(forResource: "spells-2014", ofType: "json")!
public let defaultMonsters2024Path = Bundle.module.path(forResource: "monsters-2024", ofType: "json")!
public let defaultSpells2024Path = Bundle.module.path(forResource: "spells-2024", ofType: "json")!

// Backward compatibility aliases for older call sites/tests.
public let defaultMonstersPath = defaultMonsters2014Path
public let defaultSpellsPath = defaultSpells2014Path

public extension CompendiumImportSourceId {
    static let defaultMonsters2014: Self = .init(type: "defaultContent", bookmark: "monsters")
    static let defaultSpells2014: Self = .init(type: "defaultContent", bookmark: "spells")
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
                sourceVersion: DefaultContentVersions.currentMonsters2014,
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
                sourceVersion: DefaultContentVersions.currentSpells2014,
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
                sourceVersion: DefaultContentVersions.currentMonsters2024,
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
                sourceVersion: DefaultContentVersions.currentSpells2024,
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
