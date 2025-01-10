import Foundation
@testable import Persistence
import XCTest
import InlineSnapshotTesting
import CustomDump

class KeyValueStoreVisitorManagerTest: XCTestCase {
    
    static override func setUp() {
        keyValueStoreEntities.append(TestEntity1.self)
    }

    func testRunVisitorMovingEntities() throws {
        let db = Database.uninitialized
        let sut = KeyValueStoreVisitorManager()

        try db.keyValueStore.put(TestEntity1(id: "first"))
        try db.keyValueStore.put(TestEntity1(id: "second"))
        try db.keyValueStore.put(TestEntity1(id: "third"))

        let initial = try db.keyValueStore.dump(.all)
        try sut.run(visitors: [Visitor1()], store: db.keyValueStore, conflictResolution: .overwrite)
        let result = try db.keyValueStore.dump(.all)
        let diff = diff(initial, result)

        assertInlineSnapshot(of: diff, as: .lines) {
            #"""
              """
            - 1first
            + 1firstvisited
            -   entity: {"id":"first","value":0}
            +   entity: {"id":"firstvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":4,"title":"zero"}
                idxs:   {"0":"0"}
            - 1second
            + 1secondvisited
            -   entity: {"id":"second","value":0}
            +   entity: {"id":"secondvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":4,"title":"zero"}
                idxs:   {"0":"0"}
            - 1third
            + 1thirdvisited
            -   entity: {"id":"third","value":0}
            +   entity: {"id":"thirdvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":4,"title":"zero"}
                idxs:   {"0":"0"}
              """
            """#
        }
    }

    func testRunVisitorUpdatingSecondaryIndexValues() throws {
        let db = Database.uninitialized
        let sut = KeyValueStoreVisitorManager()

        try db.keyValueStore.put(TestEntity1(id: "first"))
        try db.keyValueStore.put(TestEntity1(id: "second"))
        try db.keyValueStore.put(TestEntity1(id: "third"))

        let initial = try db.keyValueStore.dump(.all)
        try sut.run(visitors: [Visitor2()], store: db.keyValueStore, conflictResolution: .overwrite)
        let result = try db.keyValueStore.dump(.all)
        let diff = diff(initial, result)

        assertInlineSnapshot(of: diff, as: .lines) {
            #"""
              """
              1first
            -   entity: {"id":"first","value":0}
            +   entity: {"id":"first","value":1}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":1,"title":"one"}
            -   idxs:   {"0":"0"}
            +   idxs:   {"0":"1"}
              1second
            -   entity: {"id":"second","value":0}
            +   entity: {"id":"second","value":1}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":1,"title":"one"}
            -   idxs:   {"0":"0"}
            +   idxs:   {"0":"1"}
              1third
            -   entity: {"id":"third","value":0}
            +   entity: {"id":"third","value":1}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":1,"title":"one"}
            -   idxs:   {"0":"0"}
            +   idxs:   {"0":"1"}
              """
            """#
        }
    }

    func testConflictResolutionRemove() throws {
        let db = Database.uninitialized
        let sut = KeyValueStoreVisitorManager()

        try db.keyValueStore.put(TestEntity1(id: "first"))
        try db.keyValueStore.put(TestEntity1(id: "firstvisited"))

        let initial = try db.keyValueStore.dump(.all)
        try sut.run(visitors: [Visitor1()], store: db.keyValueStore, conflictResolution: .remove)
        let result = try db.keyValueStore.dump(.all)
        let diff = diff(initial, result)

        assertInlineSnapshot(of: diff, as: .lines) {
            #"""
              """
            - 1first
            + 1firstvisitedvisited
            -   entity: {"id":"first","value":0}
            +   entity: {"id":"firstvisitedvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":3,"title":"zero"}
                idxs:   {"0":"0"}
            - 1firstvisited
            -   entity: {"id":"firstvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            -   idxs:   {"0":"0"}
              """
            """#
        }
    }

    func testConflictResolutionRename() throws {
        let db = Database.uninitialized
        let sut = KeyValueStoreVisitorManager()

        try db.keyValueStore.put(TestEntity1(id: "first"))
        try db.keyValueStore.put(TestEntity1(id: "firstvisited"))
        try db.keyValueStore.put(TestEntity1(id: "firstvisited 2"))
        try db.keyValueStore.put(TestEntity1(id: "firstvisited 2 2"))
        try db.keyValueStore.put(TestEntity1(id: "firstvisited 2 2 2"))

        try db.keyValueStore.put(TestEntity1(id: "second"))
        try db.keyValueStore.put(TestEntity1(id: "secondvisited"))

        let initial = try db.keyValueStore.dump(.all)
        try sut.run(visitors: [Visitor1()], store: db.keyValueStore, conflictResolution: .rename(fallback: .remove))
        let result = try db.keyValueStore.dump(.all)
        let diff = diff(initial, result)

        assertInlineSnapshot(of: diff, as: .lines) {
            #"""
              """
            - 1first
            + 1firstvisited 2 2 2visited
            -   entity: {"id":"first","value":0}
            +   entity: {"id":"firstvisited 2 2 2visited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":11,"title":"zero"}
                idxs:   {"0":"0"}
            - 1firstvisited
            + 1firstvisited 2 2visited
            -   entity: {"id":"firstvisited","value":0}
            +   entity: {"id":"firstvisited 2 2visited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":11,"title":"zero"}
                idxs:   {"0":"0"}
            - 1firstvisited 2
            + 1firstvisited 2visited
            -   entity: {"id":"firstvisited 2","value":0}
            +   entity: {"id":"firstvisited 2visited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":11,"title":"zero"}
                idxs:   {"0":"0"}
            - 1firstvisited 2 2
            + 1firstvisitedvisited
            -   entity: {"id":"firstvisited 2 2","value":0}
            +   entity: {"id":"firstvisitedvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":11,"title":"zero"}
                idxs:   {"0":"0"}
            - 1firstvisited 2 2 2
            + 1secondvisited 2
            -   entity: {"id":"firstvisited 2 2 2","value":0}
            +   entity: {"id":"secondvisited 2","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":11,"title":"zero"}
                idxs:   {"0":"0"}
            - 1second
            + 1secondvisitedvisited
            -   entity: {"id":"second","value":0}
            +   entity: {"id":"secondvisitedvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            +   fts:    {"id":11,"title":"zero"}
                idxs:   {"0":"0"}
            - 1secondvisited
            -   entity: {"id":"secondvisited","value":0}
            -   fts:    {"id":1,"title":"zero"}
            -   idxs:   {"0":"0"}
              """
            """#
        }
    }

    struct TestEntity1: KeyValueStoreEntity, Codable, SecondaryIndexValueRepresentable, FTSDocumentConvertible, KeyConflictResolution {
        static let keyPrefix: String = "1"
        var id: String
        var key: Key { Key(id: id) }
        var value: Int = 0

        var secondaryIndexValues: [Int : String] {
            return [0: "\(value)"]
        }

        var ftsDocument: FTSDocument {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            return FTSDocument(title: formatter.string(for: value)!)
        }

        mutating func updateKeyForConflictResolution() {
            id = "\(id) 2"
        }
    }

    struct Visitor1: KeyValueStoreEntityVisitor {
        func visit(entity: inout any KeyValueStoreEntity) -> Bool {
            switch entity {
            case var entity1 as TestEntity1:
                defer { entity = entity1 }
                entity1.id = entity1.id + "visited"
                return true
            default:
                return false
            }
        }
    }

    struct Visitor2: KeyValueStoreEntityVisitor {
        func visit(entity: inout any KeyValueStoreEntity) -> Bool {
            switch entity {
            case var entity1 as TestEntity1:
                defer { entity = entity1 }
                entity1.value += 1
                return true
            default:
                return false
            }
        }
    }
}

extension DatabaseKeyValueStore {
    func dump(_ request: KeyValueStoreRequest) throws -> String {
        var result = ""
        
        let encoder = DatabaseKeyValueStore.encoder
        let keys = try fetchKeys(request)

        for k in keys {
            result += "\(k)\n"

            // add entity
            let entity = try getAny(k)
            func open<E>(_ entity: E) throws where E: KeyValueStoreEntity {
                try result += "  entity: \(String(data: encoder.encode(entity), encoding: .utf8)!)\n"
            }
            try open(entity!)

            // add fts
            let fts = try fts(for: k).map {
                try String(data: encoder.encode($0), encoding: .utf8)!
            } ?? "none"
            result += "  fts:    \(fts)\n"

            // add secondary index values
            let values = try secondaryIndexValues(for: k).map {
                try String(data: encoder.encode($0), encoding: .utf8)!
            } ?? "none"
            result += "  idxs:   \(values)\n"
        }

        return result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
