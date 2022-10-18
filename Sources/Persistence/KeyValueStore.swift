//
//  KeyValueStore.swift
//  Construct
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB
import Helpers
import GameModels

// A key-value store with FTS support built on top of GRDB
public final class KeyValueStore {

    private let queue: DatabaseQueue

    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()

    public init(_ queue: DatabaseQueue) {
        self.queue = queue
    }

    public func get<V>(_ key: String) throws -> V? where V: Codable {
        return try getRaw(key).map {
            return try Self.decoder.decode(V.self, from: $0.value)
        }
    }

    public func put<V>(_ value: V, at key: String, fts: FTSDocument? = nil, in db: GRDB.Database? = nil) throws where V: Codable {
        guard let db = db else {
            return try queue.write { db in
                try Self.put(value, at: key, fts: fts, in: db)
            }
        }

        return try Self.put(value, at: key, fts: fts, in: db)
    }

    public static func put<V>(_ value: V, at key: String, fts: FTSDocument? = nil, in db: GRDB.Database) throws where V: Codable {
        let previousLastInsertedRowId = db.lastInsertedRowID

        let encodedValue = try Self.encoder.encode(value)
        let record = Record(key: key, modifiedAt: Date(), value: encodedValue)
        try record.save(db)

        if let fts = fts {
            var rowId: Int64?
            let lastInsertedRowID = db.lastInsertedRowID

            // determine rowId of inserted/updated Record
            if previousLastInsertedRowId != lastInsertedRowID {
                rowId = lastInsertedRowID
            } else if let row = try Row.fetchOne(
                db,
                sql: "SELECT \(Column.rowID.name) FROM \(Record.databaseTableName) WHERE \(Record.Columns.key) = ?",
                arguments: [record.key]
            ) {
                rowId = row[Column.rowID]
            }

            guard let id = rowId else {
                throw KeyValueStoreError.ftsUpdateFailedWithUnavailableRowId
            }

            let ftsRecord = FTSRecord(id: id, title: fts.title, subtitle: fts.subtitle, body: fts.body)
            try ftsRecord.save(db)
        }
    }

    public func fetchAll<V>(_ keyPrefix: String) throws -> [V] where V: Codable {
        try fetchAll([keyPrefix])
    }

    public func fetchAll<V>(_ keyPrefixes: [String]? = []) throws -> [V] where V: Codable {
        return try fetchAllRaw(keyPrefixes).map {
            return try Self.decoder.decode(V.self, from: $0.value)
        }
    }

    public func match<V>(_ ftsQuery: String, keyPrefix: String? = nil) throws -> [V] where V: Codable {
        try match(ftsQuery, keyPrefixes: keyPrefix.map { [$0] })
    }

    public func match<V>(_ ftsQuery: String, keyPrefixes: [String]?) throws -> [V] where V: Codable {
        let records = try queue.read { db -> [Record] in
            var arguments: [Any] = []
            var sql = """
            SELECT \(Record.databaseTableName).*
            FROM \(Record.databaseTableName)
            """

            // FTS
            sql += """

            JOIN \(FTSRecord.databaseTableName)
                ON \(FTSRecord.databaseTableName).rowid = \(Record.databaseTableName).rowid
                AND \(FTSRecord.databaseTableName) MATCH ?
            """
            arguments.append(ftsQuery)

            // Key
            if let keyPrefixes = keyPrefixes, keyPrefixes.count > 0 {
                let prefixSql = keyPrefixes.map { _ in "\(Record.databaseTableName).key LIKE ?" }.joined(separator: " OR ")

                sql += "\n\nWHERE (\(prefixSql))"
                arguments.append(contentsOf: keyPrefixes.map { "\($0)%" })
            }

            sql += """

            ORDER BY rank
            """

            return try Record.fetchAll(db, sql: sql, arguments: StatementArguments(arguments) ?? StatementArguments())
        }
        return try records.map { try Self.decoder.decode(V.self, from: $0.value) }
    }

    @discardableResult
    public func remove(_ key: String) throws -> Bool {
        try queue.write { db in
            try Record.deleteOne(db, key: key)
        }
    }

    @discardableResult
    public func removeAll(_ keyPrefix: String) throws -> Int {
        try queue.write { db in
            try Record.filter(Column("key").like("\(keyPrefix)%")).deleteAll(db)
        }
    }

    public func contains(_ key: String, in db: GRDB.Database? = nil) throws -> Bool {
        guard let db = db else {
            return try queue.read { db in
                try contains(key, in: db)
            }
        }
        return try Record.filter(key: key).fetchCount(db) > 0
    }

    public func count(_ keyPrefix: String) throws -> Int {
        return try queue.read { db in
            return try Record.filter(Column("key").like("\(keyPrefix)%")).fetchCount(db)
        }
    }

    public func getRaw(_ key: String) throws -> Record? {
        return try queue.read { db in
            return try Record.fetchOne(db, key: key)
        }
    }

    public func fetchAllRaw(_ keyPrefix: String) throws -> [Record] {
        try fetchAllRaw([keyPrefix])
    }

    public func fetchAllRaw(_ keyPrefixes: [String]? = []) throws -> [Record] {
        return try queue.read { db in
            if let keyPrefixes = keyPrefixes {
                let filters = keyPrefixes.map { Column("key").like("\($0)%") }
                return try Record.filter(filters.joined(operator: .or)).fetchAll(db)
            } else {
                return try Record.fetchAll(db)
            }
        }
    }

    public struct Record: FetchableRecord, PersistableRecord, Codable, Hashable {
        public static var databaseTableName = "key_value"
        public enum Columns: String, ColumnExpression { case key, modified_at, value }

        public let key: String
        public let modifiedAt: Date

        var value: Data
    }

    struct FTSRecord: FetchableRecord, PersistableRecord, Codable {
        static var databaseTableName = "key_value_fts"
        static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
        enum Columns: String, ColumnExpression { case title, subtitle, body, title_suffixes }

        var id: Int64

        var title: String
        var subtitle: String?
        var body: String?
    }
}

enum KeyValueStoreError: Swift.Error {
    case ftsUpdateFailedWithUnavailableRowId
}

public struct FTSDocument {
    var title: String
    var subtitle: String?
    var body: String?
}

public extension KeyValueStore.Record {
    init(row: Row) {
        key = row[Columns.key]
        if row.hasColumn(Columns.modified_at.name) {
            modifiedAt = Date(timeIntervalSince1970: row[Columns.modified_at])
        } else {
            modifiedAt = Date(timeIntervalSince1970: 0)
        }

        value = row[Columns.value]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.key] = key
        container[Columns.modified_at] = modifiedAt.timeIntervalSince1970
        container[Columns.value] = value
    }
}

extension KeyValueStore.FTSRecord {
    init(row: Row) {
        id = row[Column.rowID]
        title = row[Columns.title]
        subtitle = row[Columns.subtitle]
        body = row[Columns.body]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Column.rowID] = id
        container[Columns.title] = title
        container[Columns.subtitle] = subtitle
        container[Columns.body] = body

        container[Columns.title_suffixes] = title.suffixes.dropFirst().joined(separator: " ")
    }
}

extension KeyValueStoreEntity {
    static func get(_ db: GRDB.Database, _ decoder: JSONDecoder, key: String) throws -> Self? {
        return try getRaw(db, key: key).map {
            return try decoder.decode(Self.self, from: $0.value)
        }
    }

    static func getRaw(_ db: GRDB.Database, key: String) throws -> KeyValueStore.Record? {
        try KeyValueStore.Record.fetchOne(db, key: key)
    }
}

public extension KeyValueStore {
    func get<V>(_ key: String, crashReporter: CrashReporter) throws -> V? where V: Codable {
        do {
            return try get(key)
        } catch let error as DecodingError {
            guard let preferences: Preferences = try? get(Preferences.key),
                  preferences.errorReportingEnabled == true else { throw error }

            let data = try? (getRaw(key)?.value)
                .flatMap { String(data: $0, encoding: .utf8) }

            crashReporter.trackError(.init(
                error: error,
                properties: [
                    "key": key,
                    "type": String(describing: V.self)
                ],
                attachments: [
                    "data": data ?? "((missing))"
                ]
            ))
            throw error
        } catch {
            throw error
        }
    }

    func get(_ itemKey: CompendiumItemKey, crashReporter: CrashReporter) throws -> CompendiumEntry? {
        try get(CompendiumEntry.key(for: itemKey), crashReporter: crashReporter)
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
}
