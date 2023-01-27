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

    public static let encoder = apply(JSONEncoder()) {
        $0.outputFormatting = [.sortedKeys]
    }
    public static let decoder = JSONDecoder()

    public init(_ queue: DatabaseQueue) {
        self.queue = queue
    }

    public func get<V>(_ key: String) throws -> V? where V: Codable {
        return try getRaw(key).map {
            return try Self.decoder.decode(V.self, from: $0.value)
        }
    }

    public func observe<V>(_ key: String) -> AsyncThrowingStream<V?, any Error> where V: Codable & Equatable {
        let observation = ValueObservation.trackingConstantRegion { db in
            try Record.fetchOne(db, key: key)
        }

        return observation.values(in: queue)
            .map { record in
                return try record.map { try Self.decoder.decode(V.self, from: $0.value) }
            }
            .removeDuplicates()
            .stream
    }

    public func put<V>(
        _ value: V,
        at key: String,
        fts: FTSDocument? = nil,
        secondaryIndexValues indexValues: [Int: String]? = nil,
        in db: GRDB.Database? = nil
    ) throws where V: Codable {
        guard let db = db else {
            return try queue.write { db in
                try Self.put(value, at: key, fts: fts, secondaryIndexValues: indexValues, in: db)
            }
        }

        return try Self.put(value, at: key, fts: fts, secondaryIndexValues: indexValues, in: db)
    }

    public static func put<V>(
        _ value: V,
        at key: String,
        fts: FTSDocument? = nil,
        secondaryIndexValues: [Int: String]? = nil,
        in db: GRDB.Database
    ) throws where V: Codable {
        let previousLastInsertedRowId = db.lastInsertedRowID

        let encodedValue = try Self.encoder.encode(value)
        let record = Record(key: key, modifiedAt: Date(), value: encodedValue)
        try record.save(db)

        if let fts {
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

        if let secondaryIndexValues {
            for (index, value) in secondaryIndexValues {
                let indexRecord = SecondaryIndexRecord(idx: index, value: value, recordKey: record.key)
                try indexRecord.save(db)
            }
        }
    }

    public func fetchAll<V>(
        _ keyPrefix: String,
        filters: [SecondaryIndexFilter] = [],
        order: [SecondaryIndexOrder] = [],
        range: Range<Int>? = nil
    ) throws -> [V] where V: Codable {
        try fetchAll([keyPrefix], filters: filters, order: order, range: range)
    }

    public func fetchAll<V>(
        _ keyPrefixes: [String]? = [],
        search: String? = nil,
        filters: [SecondaryIndexFilter] = [],
        order: [SecondaryIndexOrder] = [],
        range: Range<Int>? = nil
    ) throws -> [V] where V: Codable {
        return try fetchAllRaw(keyPrefixes, search: search, filters: filters, order: order, range: range).map {
            return try Self.decoder.decode(V.self, from: $0.value)
        }
    }

    @discardableResult
    public func remove(_ key: String) throws -> Bool {
        try queue.write { db in
            // remove FTS row
            try db.execute(
                sql: """
                DELETE FROM \(FTSRecord.databaseTableName)
                WHERE \(Column.rowID.name) IS (
                  SELECT \(Column.rowID.name) FROM \(Record.databaseTableName) WHERE key = ?
                )
                """,
                arguments: [key]
            )


            // secondary indexes are removed by a foreign key constraint

            return try Record.deleteOne(db, key: key)
        }
    }

    @discardableResult
    public func removeAll(_ keyPrefix: String) throws -> Int {
        try queue.write { db in
            // remove FTS rows
            try db.execute(
                sql: """
                DELETE FROM \(FTSRecord.databaseTableName)
                WHERE \(Column.rowID.name) IN (
                  SELECT \(Column.rowID.name) FROM \(Record.databaseTableName) WHERE key LIKE ?
                )
                """,
                arguments: ["\(keyPrefix)%"]
            )

            // secondary indexes are removed by a foreign key constraint

            // remove actual row
            return try Record.filter(Column("key").like("\(keyPrefix)%")).deleteAll(db)
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

    /// Returns an array of all keys in the store, ordered by rowId
    public func allKeys() throws -> [String] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT \(Record.Columns.key) FROM \(Record.databaseTableName) ORDER BY \(Column.rowID.name) ASC"
            ).map { row in
                row[KeyValueStore.Record.Columns.key] as String
            }
        }
    }

    public func fetchAllRaw(
        _ keyPrefix: String,
        search: String? = nil,
        filters: [SecondaryIndexFilter] = [],
        order: [SecondaryIndexOrder] = [],
        range: Range<Int>? = nil
    ) throws -> [Record] {
        try fetchAllRaw([keyPrefix], search: search, filters: filters, order: order, range: range)
    }

    public func fetchAllRaw(
        _ keyPrefixes: [String]? = [],
        search: String? = nil,
        filters: [SecondaryIndexFilter] = [],
        order: [SecondaryIndexOrder] = [],
        range: Range<Int>? = nil
    ) throws -> [Record] {

        func keyPrefixSQL(keyColumnName: String) -> (String, [String])? {
            guard let keyPrefixes = keyPrefixes, keyPrefixes.count > 0 else { return nil }

            let prefixSql = keyPrefixes.map { _ in
                "\(keyColumnName) LIKE ?"
            }.joined(separator: " OR ")

            return (prefixSql, keyPrefixes.map { "\($0)%" })
        }

        return try queue.read { db in
            var arguments: [Any] = []
            var sql: String

            let secondaryIndexes: Set<Int> = Set(filters.map(\.index) + order.map(\.index))

            sql = """
            SELECT r.*
            FROM \(Record.databaseTableName) AS r
            """

            var conditions: [(String, [Any])] = []
            for index in secondaryIndexes {
                sql += """

                INNER JOIN \(SecondaryIndexRecord.databaseTableName) AS si_\(index)
                    ON si_\(index).\(SecondaryIndexRecord.Columns.recordKey.name) = r.\(Record.Columns.key.name)
                """

                conditions.append(("si_\(index).\(SecondaryIndexRecord.Columns.idx.name) = ?", [index]))
            }


            if let search {
                sql += """

                INNER JOIN \(FTSRecord.databaseTableName)
                    ON r.\(Column.rowID.name) = \(FTSRecord.databaseTableName).\(Column.rowID.name)
                """

                conditions.append(("\(FTSRecord.databaseTableName) MATCH ?", ["\(search)*"]))
            }

            for filter in filters {
                switch filter.condition {
                case .greaterThanOrEqualTo(let s):
                    conditions.append(("si_\(filter.index).\(SecondaryIndexRecord.Columns.value.name) >= ?", [s]))
                case .lessThanOrEqualTo(let s):
                    conditions.append(("si_\(filter.index).\(SecondaryIndexRecord.Columns.value.name) <= ?", [s]))
                }
            }

            if let keyPrefixSql = keyPrefixSQL(keyColumnName: "r.\(Record.Columns.key.name)") {
                conditions.append(keyPrefixSql)
            }

            if !conditions.isEmpty {
                sql += "\nWHERE " + conditions.map { "(\($0.0))" }.joined(separator: " AND ")
                arguments.append(contentsOf: conditions.flatMap(\.1))
            }

            let fallbackSort = ["r.\(Record.Columns.key.name) ASC"]
            let orderFields = order
                .map { "si_\($0.index).\(SecondaryIndexRecord.Columns.value.name) \($0.ascDesc)" }
                .nonEmptyArray
                .map { $0 + fallbackSort }
                ?? search.map { _ in ["rank"]}
                ?? fallbackSort

            sql += "\nORDER BY " + orderFields.joined(separator: ", ")

            if let range {
                sql += "\nLIMIT \(range.startIndex), \(range.endIndex - range.startIndex)"
            }

            return try Record.fetchAll(db, sql: sql, arguments: StatementArguments(arguments) ?? .init())
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

    struct SecondaryIndexRecord: FetchableRecord, PersistableRecord, Codable {
        static var databaseTableName = "key_value_secondary_indexes"
        static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
        enum Columns: String, ColumnExpression { case idx, value, recordKey }

        var idx: Int // identifies the index (e.g. compendium item title = X, compendium monster CR = Y)
        var value: String // (e.g. "Aboleth" for compendium item title)
        var recordKey: String // the key of the corresponding Record row
    }

    public enum SecondaryIndexes {
        public static let compendiumEntryTitle = 0
        public static let compendiumEntryMonsterChallengeRating = 1
        public static let compendiumEntrySpellLevel = 2
    }

    public struct SecondaryIndexFilter {
        let index: Int
        let condition: SecondaryIndexCondition
    }

    public enum SecondaryIndexCondition {
        case greaterThanOrEqualTo(String)
        case lessThanOrEqualTo(String)
    }

    public struct SecondaryIndexOrder {
        let index: Int
        let ascending: Bool

        var ascDesc: String {
            ascending ? "ASC" : "DESC"
        }
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
}
