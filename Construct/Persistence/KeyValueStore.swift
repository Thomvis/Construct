//
//  KeyValueStore.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 04/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import GRDB

// A key-value store with FTS support built on top of GRDB
final class KeyValueStore {

    private let queue: DatabaseQueue

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    init(_ queue: DatabaseQueue) {
        self.queue = queue
    }

    func get<V>(_ key: String) throws -> V? where V: Codable {
        return try getRaw(key).map {
            return try decoder.decode(V.self, from: $0.value)
        }
    }

    func put<V>(_ value: V, at key: String, fts: FTSDocument? = nil, in db: GRDB.Database? = nil) throws where V: Codable {
        guard let db = db else {
            return try queue.write { db in
                try put(value, at: key, fts: fts, in: db)
            }
        }

        let encodedValue = try encoder.encode(value)
        let record = Record(key: key, modifiedAt: Date(), value: encodedValue)
        try record.save(db)

        if let fts = fts {
            let ftsRecord = FTSRecord(id: db.lastInsertedRowID, title: fts.title, subtitle: fts.subtitle, body: fts.body)
            try ftsRecord.save(db)
        }
    }

    func fetchAll<V>(_ keyPrefix: String) throws -> [V] where V: Codable {
        try fetchAll([keyPrefix])
    }

    func fetchAll<V>(_ keyPrefixes: [String]? = []) throws -> [V] where V: Codable {
        return try fetchAllRaw(keyPrefixes).map {
            return try decoder.decode(V.self, from: $0.value)
        }
    }

    func match<V>(_ ftsQuery: String, keyPrefix: String? = nil) throws -> [V] where V: Codable {
        try match(ftsQuery, keyPrefixes: keyPrefix.map { [$0] })
    }

    func match<V>(_ ftsQuery: String, keyPrefixes: [String]?) throws -> [V] where V: Codable {
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
        return try records.map { try decoder.decode(V.self, from: $0.value) }
    }

    @discardableResult
    func remove(_ key: String) throws -> Bool {
        try queue.write { db in
            try Record.deleteOne(db, key: key)
        }
    }

    @discardableResult
    func removeAll(_ keyPrefix: String) throws -> Int {
        try queue.write { db in
            try Record.filter(Column("key").like("\(keyPrefix)%")).deleteAll(db)
        }
    }

    func contains(_ key: String, in db: GRDB.Database? = nil) throws -> Bool {
        guard let db = db else {
            return try queue.read { db in
                try contains(key, in: db)
            }
        }
        return try Record.filter(key: key).fetchCount(db) > 0
    }

    func getRaw(_ key: String) throws -> Record? {
        return try queue.read { db in
            return try Record.fetchOne(db, key: key)
        }
    }

    func fetchAllRaw(_ keyPrefix: String) throws -> [Record] {
        try fetchAllRaw([keyPrefix])
    }

    func fetchAllRaw(_ keyPrefixes: [String]? = []) throws -> [Record] {
        return try queue.read { db in
            if let keyPrefixes = keyPrefixes {
                let filters = keyPrefixes.map { Column("key").like("\($0)%") }
                return try Record.filter(filters.joined(operator: .or)).fetchAll(db)
            } else {
                return try Record.fetchAll(db)
            }
        }
    }

    struct Record: FetchableRecord, PersistableRecord, Codable, Hashable {
        static var databaseTableName = "key_value"

        let key: String
        let modifiedAt: Date

        let value: Data
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

struct FTSDocument {
    var title: String
    var subtitle: String?
    var body: String?
}

extension KeyValueStore.Record {
    init(row: Row) {
        key = row["key"]
        if row.hasColumn("modified_at") {
            modifiedAt = Date(timeIntervalSince1970: row["modified_at"])
        } else {
            modifiedAt = Date(timeIntervalSince1970: 0)
        }

        value = row["value"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["key"] = key
        container["modified_at"] = modifiedAt.timeIntervalSince1970
        container["value"] = value
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
