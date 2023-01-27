//
//  Compendium.swift
//  Construct
//
//  Created by Thomas Visser on 19/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Combine
import GRDB
import GameModels
import Helpers
import Compendium

public class DatabaseCompendium: Compendium {

    public let database: Database
    public let fallback: ExternalCompendium

    public init(database: Database, fallback: ExternalCompendium = .empty) {
        self.database = database
        self.fallback = fallback
    }

    public func get(_ key: CompendiumItemKey) throws -> CompendiumEntry? {
        try database.keyValueStore.get(key)
    }

    public func get(_ key: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry? {
        try database.keyValueStore.get(key, crashReporter: crashReporter)
    }

    public func put(_ entry: CompendiumEntry) throws {
        try database.keyValueStore.put(entry, fts: entry.ftsDocument, secondaryIndexValues: entry.secondaryIndexValues)
    }

    public func contains(_ key: GameModels.CompendiumItemKey) throws -> Bool {
        try database.keyValueStore.contains(CompendiumEntry.key(for: key))
    }

    public func fetchAll(
        search: String?,
        filters: CompendiumFilters? = nil,
        order: Order?,
        range: Range<Int>?
    ) throws -> [CompendiumEntry] {
        let typeKeyPrefixes = filters?.types.map { $0.map { CompendiumEntry.keyPrefix(for: $0) } } ?? [CompendiumEntry.keyPrefix(for: nil)]
        return try self.database.keyValueStore.fetchAll(
            typeKeyPrefixes,
            search: search,
            filters: filters?.secondaryIndexFilters ?? [],
            order: order.map(KeyValueStore.SecondaryIndexOrder.init).nonNilArray,
            range: range
        )
    }

    public func resolve(annotation: CompendiumItemReferenceTextAnnotation) -> ReferenceResolveResult {
        let internalResults = try? fetchAll(search: annotation.text, filters: .init(types: annotation.type.map { [$0] }), order: .title, range: nil)

        if let exactMatch = internalResults?.first(where: { $0.item.title.caseInsensitiveCompare(annotation.text) == .orderedSame }) {
            return .internal(CompendiumItemReference(itemTitle: exactMatch.item.title, itemKey: exactMatch.item.key))
        }

        // Prefer results with a shorter title, so that "shield" does not match "fire shield" before "shield"
        if let first = internalResults?.sorted(by: { $0.item.title.count < $1.item.title.count }).first {
            return .internal(CompendiumItemReference(itemTitle: first.item.title, itemKey: first.item.key))
        }

        if let external = fallback.url(for: annotation) {
            return .external(external)
        }

        return .notFound
    }
}

public extension CompendiumItemField {
    static func challengeRatingIndexValue(from fraction: Fraction) -> String {
        fraction.double
            .formatted(.number.precision(
                .integerAndFractionLength(integerLimits: 3...3, fractionLimits: 0...3)
            ))
    }
}

extension CompendiumEntry {
    var ftsDocument: FTSDocument {
        Persistence.FTSDocument(title: item.title, subtitle: nil, body: nil)
    }

    var secondaryIndexValues: [Int: String] {
        var values: [Int: String] = [KeyValueStore.SecondaryIndexes.compendiumEntryTitle: item.title]
        if let monster = item as? Monster {
            // format the CR so that it sorts correctly, examples:
            // CR 1/4 = 000.25
            // CR 1   = 001
            // CR 10  = 010
            let cr = CompendiumItemField.challengeRatingIndexValue(from: monster.challengeRating)
            values[KeyValueStore.SecondaryIndexes.compendiumEntryMonsterChallengeRating] = cr

            if let type = monster.stats.type?.result?.value?.rawValue {
                values[KeyValueStore.SecondaryIndexes.compendiumEntryMonsterType] = type
            }
        } else if let spell = item as? Spell {
            let levelString = spell.level.map { "\($0)" } ?? "0"
            values[KeyValueStore.SecondaryIndexes.compendiumEntrySpellLevel] = levelString
            // use title as tie breaker?
        }
        return values
    }
}

extension DatabaseCompendium {
    public static func put(_ entry: CompendiumEntry, in db: GRDB.Database) throws {
        try KeyValueStore.put(entry, fts: entry.ftsDocument, in: db)
    }
}

public extension KeyValueStore {
    func get(_ itemKey: CompendiumItemKey) throws -> CompendiumEntry? {
        return try get(CompendiumEntry.key(for: itemKey))
    }

    @discardableResult
    func remove(_ itemKey: CompendiumItemKey) throws -> Bool {
        try remove(CompendiumEntry.key(for: itemKey))
    }

    func get(_ itemKey: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry? {
        try get(CompendiumEntry.key(for: itemKey), crashReporter: crashReporter)
    }
}

extension KeyValueStore.SecondaryIndexOrder {
    init(_ order: Order) {
        switch order.key {
        case .title: self.index = KeyValueStore.SecondaryIndexes.compendiumEntryTitle
        case .monsterChallengeRating: self.index = KeyValueStore.SecondaryIndexes.compendiumEntryMonsterChallengeRating
        case .spellLevel: self.index = KeyValueStore.SecondaryIndexes.compendiumEntrySpellLevel
        }
        self.ascending = order.ascending
    }
}

extension CompendiumFilters {
    var secondaryIndexFilters: [KeyValueStore.SecondaryIndexFilter] {
        Array(builder: {
            if let minMonsterChallengeRating {
                KeyValueStore.SecondaryIndexFilter(
                    index: KeyValueStore.SecondaryIndexes.compendiumEntryMonsterChallengeRating,
                    condition: .greaterThanOrEqualTo(CompendiumItemField.challengeRatingIndexValue(from: minMonsterChallengeRating))
                )
            }

            if let maxMonsterChallengeRating {
                KeyValueStore.SecondaryIndexFilter(
                    index: KeyValueStore.SecondaryIndexes.compendiumEntryMonsterChallengeRating,
                    condition: .lessThanOrEqualTo(CompendiumItemField.challengeRatingIndexValue(from: maxMonsterChallengeRating))
                )
            }

            if let monsterType {
                KeyValueStore.SecondaryIndexFilter(
                    index: KeyValueStore.SecondaryIndexes.compendiumEntryMonsterType,
                    condition: .equals(monsterType.rawValue)
                )
            }
        })
    }
}
