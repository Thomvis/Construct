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

class Compendium {
    let database: Database

    init(_ database: Database) {
        self.database = database
    }

    func get(_ key: CompendiumItemKey) throws -> CompendiumEntry? {
        try database.keyValueStore.get(key)
    }

    func put(_ entry: CompendiumEntry, in db: GRDB.Database? = nil) throws {
        try database.keyValueStore.put(entry, fts: FTSDocument(title: entry.item.title, subtitle: nil, body: nil), in: db)
    }

    func fetchAll(query: String?, types: [CompendiumItemType]? = []) throws -> [CompendiumEntry] {
        let entries: [CompendiumEntry]
        let typeKeyPrefixes = types.map { $0.map { CompendiumEntry.keyPrefix(for: $0) } } ?? [CompendiumEntry.keyPrefix(for: nil)]
        if let query = query {
            entries = try self.database.keyValueStore.match("\(query)*", keyPrefixes: typeKeyPrefixes)
        } else {
            entries = try self.database.keyValueStore.fetchAll(typeKeyPrefixes)
        }
        return entries
    }

    func resolve(annotation: CompendiumItemReferenceTextAnnotation, fallback: ExternalCompendium = DndBeyondExternalCompendium()) -> ReferenceResolveResult {
        let internalResults = try? fetchAll(query: annotation.text, types: annotation.type.map { [$0] })

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


    enum ReferenceResolveResult {
        case `internal`(CompendiumItemReference)
        case external(URL)
        case notFound
    }
}
