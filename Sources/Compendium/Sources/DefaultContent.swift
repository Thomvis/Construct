//
//  DefaultContent.swift
//  
//
//  Created by Thomas Visser on 02/10/2022.
//

import Foundation
import GameModels

public enum DefaultContentRuleset: String, CaseIterable, Codable, Hashable, Sendable {
    case rules2014
    case rules2024

    public var document: CompendiumSourceDocument {
        switch self {
        case .rules2014:
            CompendiumSourceDocument.srd5_1
        case .rules2024:
            CompendiumSourceDocument.srd5_2
        }
    }

    public var edition: DefaultContentEdition {
        switch self {
        case .rules2014:
            .rules2014
        case .rules2024:
            .rules2024
        }
    }

    public var sources: Set<DefaultContentSource> {
        switch self {
        case .rules2014:
            [.monsters2014, .spells2014]
        case .rules2024:
            [.monsters2024, .spells2024]
        }
    }
}

public enum DefaultContentSource: String, CaseIterable, Codable, Hashable, Sendable {
    case monsters2014
    case spells2014
    case monsters2024
    case spells2024

    public static let currentMonsters2014Version = "2026.06.01"
    public static let currentSpells2014Version = "2026.06.01"
    public static let currentMonsters2024Version = "2026.06.01"
    public static let currentSpells2024Version = "2026.06.01"

    public var currentVersion: String {
        switch self {
        case .monsters2014:
            Self.currentMonsters2014Version
        case .spells2014:
            Self.currentSpells2014Version
        case .monsters2024:
            Self.currentMonsters2024Version
        case .spells2024:
            Self.currentSpells2024Version
        }
    }

    public var document: CompendiumSourceDocument {
        ruleset.document
    }

    public var edition: DefaultContentEdition {
        ruleset.edition
    }

    public var importSourceId: CompendiumImportSourceId {
        switch self {
        case .monsters2014:
            .defaultMonsters2014
        case .spells2014:
            .defaultSpells2014
        case .monsters2024:
            .defaultMonsters2024
        case .spells2024:
            .defaultSpells2024
        }
    }

    public var ruleset: DefaultContentRuleset {
        switch self {
        case .monsters2014, .spells2014:
            .rules2014
        case .monsters2024, .spells2024:
            .rules2024
        }
    }
}

public struct DefaultContentVersions: Codable, Hashable {

    public let versions: [DefaultContentSource: String]

    public init(versions: [DefaultContentSource: String]) {
        self.versions = versions
    }
}

public extension DefaultContentVersions {

    static let current = Self(
        versions: Dictionary(
            uniqueKeysWithValues: DefaultContentSource.allCases.map { source in
                (source, source.currentVersion)
            }
        )
    )

    static let empty = Self(versions: [:])

    var rulesets: Set<DefaultContentRuleset> {
        Set(sources.map { $0.ruleset })
    }

    var sources: Set<DefaultContentSource> {
        Set(versions.keys)
    }
    
    func filter(on ruleset: DefaultContentRuleset) -> DefaultContentVersions {
        DefaultContentVersions(versions: versions.filter { source, version in source.ruleset == ruleset })
    }

    static func sourcesNeedingImport(
        selection: Set<DefaultContentRuleset>,
        installed: DefaultContentVersions?
    ) -> Set<DefaultContentSource> {
        guard !selection.isEmpty else { return [] }

        let installed = installed ?? .empty
        var sources: Set<DefaultContentSource> = []

        for ruleset in selection {
            sources.formUnion(ruleset.sources.filter { source in
                installed.version(for: source) != source.currentVersion
            })
        }

        return sources
    }

    func version(for source: DefaultContentSource) -> String? {
        versions[source]
    }
}

public let defaultMonsters2014Path = Bundle.module.path(forResource: "monsters-2014", ofType: "json")!
public let defaultSpells2014Path = Bundle.module.path(forResource: "spells-2014", ofType: "json")!
public let defaultMonsters2024Path = Bundle.module.path(forResource: "monsters-2024", ofType: "json")!
public let defaultSpells2024Path = Bundle.module.path(forResource: "spells-2024", ofType: "json")!

public extension CompendiumImportSourceId {
    static let defaultMonsters2014: Self = .init(type: "defaultContent", bookmark: "monsters")
    static let defaultSpells2014: Self = .init(type: "defaultContent", bookmark: "spells")
    static let defaultMonsters2024: Self = .init(type: "defaultContent", bookmark: "monsters-2024")
    static let defaultSpells2024: Self = .init(type: "defaultContent", bookmark: "spells-2024")
}

public extension CompendiumImporter {
    private func importDefaultContentSource(_ source: DefaultContentSource) async throws {
        switch source {
        case .monsters2014:
            _ = try await run(CompendiumImportTask(
                sourceId: source.importSourceId,
                sourceVersion: source.currentVersion,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultMonsters2014Path).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: source.document,
                overwriteExisting: true
            ))

        case .spells2014:
            _ = try await run(CompendiumImportTask(
                sourceId: source.importSourceId,
                sourceVersion: source.currentVersion,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultSpells2014Path).decode(type: [O5e.Spell].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: source.document,
                overwriteExisting: true
            ))

        case .monsters2024:
            _ = try await run(CompendiumImportTask(
                sourceId: source.importSourceId,
                sourceVersion: source.currentVersion,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultMonsters2024Path).decode(type: [O5e.Monster].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: source.document,
                overwriteExisting: true
            ))

        case .spells2024:
            _ = try await run(CompendiumImportTask(
                sourceId: source.importSourceId,
                sourceVersion: source.currentVersion,
                reader: Open5eDataSourceReader(
                    dataSource: FileDataSource(path: defaultSpells2024Path).decode(type: [O5e.Spell].self).toOpen5eAPIResults(),
                    generateUUID: { UUID() }
                ),
                document: source.document,
                overwriteExisting: true
            ))
        }
    }

    func importDefaultContent(
        sources: Set<DefaultContentSource> = Set(DefaultContentSource.allCases)
    ) async throws {
        for source in sources {
            try await importDefaultContentSource(source)
        }
    }
}
