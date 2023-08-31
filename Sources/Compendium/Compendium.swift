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
    var metadata: CompendiumMetadata { get }

    func get(_ key: CompendiumItemKey) throws -> CompendiumEntry?
    func get(_ key: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry?
    func put(_ entry: CompendiumEntry) throws
    func contains(_ key: CompendiumItemKey) throws -> Bool
    func fetchAll(search: String?, filters: CompendiumFilters?, order: Order?, range: Range<Int>?) throws -> [CompendiumEntry]
    func resolve(annotation: CompendiumItemReferenceTextAnnotation) -> ReferenceResolveResult
}

public enum CompendiumItemField: Equatable {
    case title
    case monsterChallengeRating
    case spellLevel
}

public struct Order: Equatable {
    public let key: CompendiumItemField
    public let ascending: Bool

    public static let title = Order(key: .title, ascending: true)
    public static let monsterChallengeRating = Order(key: .monsterChallengeRating, ascending: true)

    public static func `default`(_ itemTypes: [CompendiumItemType]) -> Self {
        if let single = itemTypes.single {
            switch single {
            case .monster: return .init(key: .monsterChallengeRating, ascending: true)
            case .spell: return .init(key: .spellLevel, ascending: true)
            case .character, .group: break
            }
        }

        // multiple types & fallback
        return .title
    }
}

public struct CompendiumFilters: Equatable {
    public var source: Source?
    public var types: [CompendiumItemType]?

    public var minMonsterChallengeRating: Fraction? = nil
    public var maxMonsterChallengeRating: Fraction? = nil
    public var monsterType: MonsterType? = nil

    public init(
        source: Source? = nil,
        types: [CompendiumItemType]? = nil,
        minMonsterChallengeRating: Fraction? = nil,
        maxMonsterChallengeRating: Fraction? = nil,
        monsterType: MonsterType? = nil
    ) {
        self.source = source
        self.types = types
        self.minMonsterChallengeRating = minMonsterChallengeRating
        self.maxMonsterChallengeRating = maxMonsterChallengeRating
        self.monsterType = monsterType
    }

    public enum Property: CaseIterable, Equatable {
        case itemType
        case minMonsterCR
        case maxMonsterCR
        case monsterType
    }

    public struct Source: Hashable {
        public var realm: CompendiumRealm
        public var document: CompendiumSourceDocument

        public init(realm: CompendiumRealm, document: CompendiumSourceDocument) {
            self.realm = realm
            self.document = document
        }
    }
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

            _ = try await CompendiumImporter(compendium: self).run(task)
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

            _ = try await CompendiumImporter(compendium: self).run(task)
        }
    }
}
