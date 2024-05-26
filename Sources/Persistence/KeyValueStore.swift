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
import Dependencies

public protocol KeyValueStore {
    func get<V>(_ type: V.Type, key: String) throws -> V? where V: Codable
    func observe<V>(_ key: String) -> AsyncThrowingStream<V?, any Error> where V: Codable & Equatable
    func put<V>(_ value: V, at key: String, fts: FTSDocument?, secondaryIndexValues indexValues: [Int: String]?) throws where V: Codable
    @discardableResult
    func remove(_ key: String) throws -> Bool
    func contains(_ key: String) throws -> Bool

    func fetchAll<V>(_ request: KeyValueStoreRequest) throws -> [V] where V: Decodable
    func observeAll<V>(_ request: KeyValueStoreRequest) -> AsyncThrowingStream<[V], any Error> where V: Codable & Equatable
    func removeAll(_ request: KeyValueStoreRequest) throws -> Int
    func count(_ request: KeyValueStoreRequest) throws -> Int

    func fetchKeys(_ request: KeyValueStoreRequest) throws -> [String]

    func transaction(_ updates: (KeyValueStore) throws -> Void) throws -> Void
}

public extension KeyValueStore {
    func get<V>(_ key: String) throws -> V? where V: Codable {
        try get(V.self, key: key)
    }

    func put<V>(
        _ value: V,
        at key: String
    ) throws where V: Codable {
        try put(value, at: key, fts: nil, secondaryIndexValues: nil)
    }

    func put<V>(
        _ value: V,
        at key: String,
        fts: FTSDocument?
    ) throws where V: Codable {
        try put(value, at: key, fts: fts, secondaryIndexValues: nil)
    }

    func put<V>(
        _ value: V,
        at key: String,
        secondaryIndexValues indexValues: [Int: String]?
    ) throws where V: Codable {
        try put(value, at: key, fts: nil, secondaryIndexValues: indexValues)
    }
}

/// A KeyValueStore implementation using GRDB (SQLite)
public final class DatabaseKeyValueStore: KeyValueStore {

    private let database: DatabaseAccess

    public static let encoder = apply(JSONEncoder()) {
        $0.outputFormatting = [.sortedKeys]
    }
    public static let decoder = JSONDecoder()

    public init(_ database: DatabaseAccess) {
        self.database = database
    }

    public func get<V>(_ type: V.Type, key: String) throws -> V? where V: Codable {
        return try database.read { db in
            try Record.fetchOne(db, key: key)
        }.map {
            try Self.decode(V.self, from: $0)
        }
    }

    public func observe<V>(_ key: String) -> AsyncThrowingStream<V?, any Error> where V: Codable & Equatable {

        let observation = ValueObservation.trackingConstantRegion { db in
            try Record.fetchOne(db, key: key)
        }

        return database.observe(observation)
            .map { record in
                return try record.map { try Self.decode(V.self, from: $0) }
            }
            .removeDuplicates()
            .stream
    }

    public func put<V>(
        _ value: V,
        at key: String,
        fts: FTSDocument?,
        secondaryIndexValues: [Int: String]?
    ) throws where V: Codable {
        let fts = fts ?? (value as? FTSDocumentConvertible)?.ftsDocument
        let secondaryIndexValues = secondaryIndexValues
            ?? (value as? SecondaryIndexValueRepresentable)?.secondaryIndexValues

        try database.write { db in
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
                try Self.saveSecondaryIndexValues(secondaryIndexValues, recordKey: record.key, in: db)
            }
        }
    }

    @discardableResult
    public func remove(_ key: String) throws -> Bool {
        return try database.write { db in
//            // remove FTS row
//            try db.execute(
//                sql: """
//            DELETE FROM \(FTSRecord.databaseTableName)
//            WHERE \(Column.rowID.name) IS (
//              SELECT \(Column.rowID.name) FROM \(Record.databaseTableName) WHERE key = ?
//            )
//            """,
//                arguments: [key]
//            )


            // secondary indexes are removed by a foreign key constraint

            return try Record.deleteOne(db, key: key)
        }
    }

    public func contains(_ key: String) throws -> Bool {
        return try database.read { db in
            try Record.filter(key: key).fetchCount(db) > 0
        }
    }

    public func fetchAll<V>(_ request: KeyValueStoreRequest) throws -> [V] where V : Decodable {
        try getAllRaw(request).map {
            return try Self.decode(V.self, from: $0)
        }
    }

    public func fetchKeys(_ request: KeyValueStoreRequest) throws -> [String] {
        let query = Self.build(request: request)
            .select(Record.Columns.key)
            .asRequest(of: String.self)

        return try database.read { db in
            try print(query.makePreparedRequest(db).statement)
            return try query.fetchAll(db)
        }
    }

    public func observeAll<V>(_ request: KeyValueStoreRequest) -> AsyncThrowingStream<[V], Error> where V : Decodable, V : Encodable, V : Equatable {
        let observation = ValueObservation.trackingConstantRegion { db in
            let store = DatabaseKeyValueStore(DirectDatabaseAccess(db: db))
            return try store.getAllRaw(request)
        }

        return database.observe(observation)
            .map { records in
                try records.map { try Self.decode(V.self, from: $0) }
            }
            .removeDuplicates()
            .stream
    }

    public func removeAll(_ request: KeyValueStoreRequest) throws -> Int {
        try database.write { db in
            return try Self.build(request: request).deleteAll(db)
        }
    }

    public func count(_ request: KeyValueStoreRequest) throws -> Int {
        return try database.write { db in
            return try Self.build(request: request).fetchCount(db)
        }
    }

    public func transaction(_ updates: (KeyValueStore) throws -> Void) throws {
        return try database.write { db in
            try updates(DatabaseKeyValueStore(DirectDatabaseAccess(db: db)))
        }
    }

    public struct Record: FetchableRecord, PersistableRecord, Codable, Hashable {
        public static var databaseTableName = "key_value"
        public enum Columns: String, ColumnExpression { case key, modified_at, value }
        static let secondaryIndex: HasManyAssociation<Self, SecondaryIndexRecord> = hasMany(SecondaryIndexRecord.self)
        static func secondaryIndex(_ idx: Int) -> HasManyAssociation<Self, SecondaryIndexRecord> {
            hasMany(SecondaryIndexRecord.self, key: "\(idx)")
        }
        static let fts = hasOne(FTSRecord.self, using: ForeignKey([Column.rowID], to: [Column.rowID]))

        public let key: String
        public let modifiedAt: Date

        var value: Data
    }

    private static func decode<T>(_ type: T.Type, from record: Record) throws -> T where T : Decodable {
        do {
            return try Self.decoder.decode(type, from: record.value)
        } catch let error as DecodingError {
            throw DatabaseKeyValueStoreError.decodingError(record.value, error)
        }
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

        static let record = belongsTo(Record.self)
    }
}

/// All helper methods
extension DatabaseKeyValueStore {
    private func getAllRaw(_ request: KeyValueStoreRequest) throws -> [Record] {
        try database.read { db in
            try Self.build(request: request).fetchAll(db)
        }
    }

    static func saveSecondaryIndexValues(_ secondaryIndexValues: [Int: String], recordKey: String, in db: GRDB.Database) throws {
        for (index, value) in secondaryIndexValues {
            let indexRecord = SecondaryIndexRecord(idx: index, value: value, recordKey: recordKey)
            try indexRecord.save(db)
        }
    }

    private static func build(request: KeyValueStoreRequest) -> QueryInterfaceRequest<Record> {
        var query = Record.all()

        // Create aliases for each secondary index (used below for filtering and sorting)
        let secondaryIndexTableAliases: [Int: TableAlias] = Set(
            (request.filters?.map(\.index) ?? []) + (request.order?.map(\.index) ?? [])
        ).reduce(into: [:]) { acc, elem in
            acc[elem] = TableAlias()
        }

        for alias in secondaryIndexTableAliases {
            query = query.joining(
                required: Record.secondaryIndex(alias.key)
                    .aliased(alias.value)
                    .filter(alias.value[SecondaryIndexRecord.Columns.idx] == alias.key)
            )
        }

        if let filters = request.filters?.nonEmptyArray {
            for filter in filters {
                let column = secondaryIndexTableAliases[filter.index]![SecondaryIndexRecord.Columns.value]
                switch filter.condition {
                case .greaterThanOrEqualTo(let v):
                    query = query.filter(column >= v)
                case .lessThanOrEqualTo(let v):
                    query = query.filter(column <= v)
                case .equals(let v):
                    query = query.filter(column == v)
                }
            }
        }

        if let keyPrefixes = request.keyPrefixes?.nonEmptyArray {
            query = query.filter(keyPrefixes.map { p in Record.Columns.key.like("\(p)%") }.joined(operator: .or))
        }

        let ftsTableAlias = TableAlias()
        if let search = request.fullTextSearch {
            query = query.joining(
                required: Record.fts
                    .aliased(ftsTableAlias)
                    .matching(FTS5Pattern(matchingAllPrefixesIn: search))
            )
        }

        let fallbackSort = Record.Columns.key.asc
        if let order = request.order?.nonEmptyArray {
            query = query.order(order.map { o in
                let column = secondaryIndexTableAliases[o.index]![SecondaryIndexRecord.Columns.value]
                return o.ascending ? column.asc : column.desc
            } + [fallbackSort])
        } else if request.fullTextSearch != nil {
            query = query.order(ftsTableAlias[Column.rank])
        } else {
            query = query.order(fallbackSort)
        }

        if let range = request.range {
            query = query.limit(range.count, offset: range.startIndex)
        }

        return query
    }
}

// For testing/debugging
extension DatabaseKeyValueStore {
    func secondaryIndexValues(for key: String) throws -> [Int: String]? {
        let values = try database.read { db in
            try Record(key: key, modifiedAt: Date(), value: Data()).request(for: Record.secondaryIndex).fetchAll(db)
        }

        guard !values.isEmpty else { return nil }

        return Dictionary(uniqueKeysWithValues: values.map { ($0.idx, $0.value) })
    }

    func fts(for key: String) throws -> FTSRecord? {
        return try database.read { db in
            try Record.select(Column.rowID).asRequest(of: Row.self).fetchOne(db).flatMap { row in
                let cid = row[Column.rowID]
                return try FTSRecord.filter(Column.rowID == cid).fetchOne(db)
            }
        }
    }
}

fileprivate enum KeyValueStoreDatabase: DependencyKey {
    static var liveValue: GRDB.Database? = nil
}

fileprivate extension DependencyValues {
    var keyValueStoreDatabase: GRDB.Database? {
        get { self[KeyValueStoreDatabase.self] }
        set { self[KeyValueStoreDatabase.self] = newValue }
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

public enum SecondaryIndexes: Hashable {
    public static let compendiumEntryTitle = 0
    public static let compendiumEntryMonsterChallengeRating = 1
    public static let compendiumEntrySpellLevel = 2
    public static let compendiumEntryMonsterType = 3
    public static let compendiumEntrySourceDocumentId = 4
}

public struct SecondaryIndexFilter {
    let index: Int
    let condition: SecondaryIndexCondition
}

public enum SecondaryIndexCondition {
    case greaterThanOrEqualTo(String)
    case lessThanOrEqualTo(String)
    case equals(String)
}

public struct SecondaryIndexOrder {
    let index: Int
    let ascending: Bool

    var ascDesc: String {
        ascending ? "ASC" : "DESC"
    }
}

public protocol FTSDocumentConvertible {
    var ftsDocument: FTSDocument { get }
}

public protocol SecondaryIndexValueRepresentable {
    var secondaryIndexValues: [Int: String] { get }
}

public extension DatabaseKeyValueStore.Record {
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

extension DatabaseKeyValueStore.FTSRecord {
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
        } catch {
            guard let preferences: Preferences = try? get(Preferences.key),
                  preferences.errorReportingEnabled == true else { throw error }

            let data: String?
            switch error {
            case DatabaseKeyValueStoreError.decodingError(let d, _):
                data = String(data: d, encoding: .utf8)
            default:
                data = nil
            }

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
        }
    }
}

enum DatabaseKeyValueStoreError: Error {
    case decodingError(Data, DecodingError)
}
