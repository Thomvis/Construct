import Foundation
import GameModels
import XCTest
import SnapshotTesting
import TestSupport
import Helpers
import CustomDump

final class UpdateEntryDocumentGameModelsVisitorTest: XCTestCase {
    
    var fixtures: VisitorTestFixtures!
    
    override func setUp() {
        super.setUp()
        self.fixtures = VisitorTestFixtures()
    }

    override func invokeTest() {
        withSnapshotTesting(diffTool: .ksdiff) {
            super.invokeTest()
        }
    }

    func testUpdateDocumentDisplayName() {
        let targetDocument = apply(fixtures.document) {
            $0.displayName = "Doc 2"
        }
        
        let sut = UpdateEntryDocumentGameModelsVisitor(
            originalDocumentId: fixtures.document.id,
            targetDocument: targetDocument
        )

        // Test entries in the document
        // Asserting that:
        // - visit returns true because the entry changed
        // - in the snapshot:
        //   - the name of the document in the entry changed
        // - a second visit returns false
        var entry1 = fixtures.entryInDocument1
        XCTAssertTrue(sut.visit(entry: &entry1))
        assertSnapshot(of: diff(fixtures.entryInDocument1, entry1) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &entry1)) // No changes on second visit

        // Asserting that:
        // - visit returns true because the entry changed
        // - in the snapshot:
        //   - the name of the document in the entry changed
        // - a second visit returns false
        var entry2 = fixtures.entryInDocument2
        XCTAssertTrue(sut.visit(entry: &entry2))
        assertSnapshot(of: diff(fixtures.entryInDocument2, entry2) ?? "", as: .lines)
        XCTAssertFalse(sut.visit(entry: &entry2))
        
        // Test entry not in document
        // Asserting that:
        // - visit returns false because it does not match the original document id
        // - no changes were made to the entry
        var entryNotInDoc = fixtures.entryNotInDocument
        XCTAssertFalse(sut.visit(entry: &entryNotInDoc))
        expectNoDifference(fixtures.entryNotInDocument, entryNotInDoc)
    }
    
    func testUpdateDocumentId() {
        let targetDocument = apply(fixtures.document) {
            $0.id = .init("newdoc")
        }
        
        let sut = UpdateEntryDocumentGameModelsVisitor(
            originalDocumentId: fixtures.document.id,
            targetDocument: targetDocument
        )

        // Asserting that:
        // - visit returns true because the entry changed
        // - in the snapshot:
        //   - the id of the document in the entry changed
        // - a second visit returns false
        var entry1 = fixtures.entryInDocument1
        XCTAssertTrue(sut.visit(entry: &entry1))
        assertSnapshot(of: diff(fixtures.entryInDocument1, entry1) ?? "", as: .lines)
        XCTAssertEqual(entry1.document.id.rawValue, "newdoc")

        // Asserting that:
        // - visit returns true because the entry changed
        // - in the snapshot:
        //   - the id of the document in the entry changed
        // - a second visit returns false
        var entry2 = fixtures.entryInDocument2
        XCTAssertTrue(sut.visit(entry: &entry2))
        assertSnapshot(of: diff(fixtures.entryInDocument2, entry2) ?? "", as: .lines)
        XCTAssertEqual(entry2.document.id.rawValue, "newdoc")
        
        // Test entry not in document
        // Asserting that:
        // - visit returns false because it does not match the original document id
        // - no changes were made to the entry
        var entryNotInDoc = fixtures.entryNotInDocument
        XCTAssertFalse(sut.visit(entry: &entryNotInDoc))
        XCTAssertEqual(fixtures.entryNotInDocument, entryNotInDoc)
    }
    
    func testUpdateRealmId() {
        let targetDocument = apply(fixtures.document) {
            $0.realmId = .init("newrealm")
        }
        
        let sut = UpdateEntryDocumentGameModelsVisitor(
            originalDocumentId: fixtures.document.id,
            targetDocument: targetDocument
        )

        // Asserting that:
        // - visit returns true because the entry changed
        // - in the snapshot:
        //   - the realm id in the item key has changed
        // - a second visit returns false
        var entry1 = fixtures.entryInDocument1
        XCTAssertTrue(sut.visit(entry: &entry1))
        assertSnapshot(of: diff(fixtures.entryInDocument1, entry1) ?? "", as: .lines)
        XCTAssertEqual(entry1.item.realm.value, "newrealm")

        // Asserting that:
        // - visit returns true because the entry changed
        // - in the snapshot:
        //   - the realm id in the item key has changed
        // - a second visit returns false
        var entry2 = fixtures.entryInDocument2
        XCTAssertTrue(sut.visit(entry: &entry2))
        assertSnapshot(of: diff(fixtures.entryInDocument2, entry2) ?? "", as: .lines)
        XCTAssertEqual(entry2.item.realm.value, "newrealm")
    }
} 
