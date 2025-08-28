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
    
    func fetch(_ request: CompendiumFetchRequest) throws -> [CompendiumEntry]
    func fetchKeys(_ request: CompendiumFetchRequest) throws -> [CompendiumItemKey]
    func count(_ request: CompendiumFetchRequest) throws -> Int
    
    func resolve(annotation: CompendiumItemReferenceTextAnnotation) -> ReferenceResolveResult
}

public extension Compendium {
    // Default implementations that map old methods to new ones
    func fetchAll(
        search: String? = nil,
        filters: CompendiumFilters? = nil,
        order: Order? = nil,
        range: Range<Int>? = nil
    ) throws -> [CompendiumEntry] {
        try fetch(CompendiumFetchRequest(
            search: search,
            filters: filters,
            order: order,
            range: range
        ))
    }

    func fetchKeys(
        search: String? = nil,
        filters: CompendiumFilters? = nil,
        order: Order? = nil,
        range: Range<Int>? = nil
    ) throws -> [CompendiumItemKey] {
        try fetchKeys(CompendiumFetchRequest(
            search: search,
            filters: filters,
            order: order,
            range: range
        ))
    }
}

struct CompendiumQuery {
    let search: String?
    let filters: CompendiumFilters?
    let order: Order?
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
    public static let spellLevel = Order(key: .spellLevel, ascending: true)

    public static func `default`(_ itemTypes: [CompendiumItemType]) -> Self {
        if let single = itemTypes.single {
            switch single {
            case .monster: return .monsterChallengeRating
            case .spell: return .spellLevel
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
        case source
        case itemType
        case minMonsterCR
        case maxMonsterCR
        case monsterType
    }

    // TODO: merge with CompendiumSourceDocumentKey
    public struct Source: Hashable {
        public var realm: CompendiumRealm.Id
        public var document: CompendiumSourceDocument.Id

        public init(realm: CompendiumRealm.Id, document: CompendiumSourceDocument.Id) {
            self.realm = realm
            self.document = document
        }

        public init(_ document: CompendiumSourceDocument) {
            self.realm = document.realmId
            self.document = document.id
        }
    }
}

public enum ReferenceResolveResult {
    case `internal`(CompendiumItemReference)
    case external(URL)
    case notFound
}

public enum TransferMode: Int {
    case copy = 0
    case move = 1
}

public enum ConflictResolution: Equatable, CaseIterable {
    case skip
    case overwrite
    case keepBoth
}

public enum CompendiumItemSelection: Equatable {
    case single(CompendiumItemKey)
    case multiple(CompendiumFetchRequest)
}
