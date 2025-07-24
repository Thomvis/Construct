import Foundation
import GameModels
import XCTest
import SnapshotTesting
import TestSupport
import Helpers
import CustomDump

final class UpdateImportJobDocumentGameModelsVisitorTest: XCTestCase {
    var fixtures: VisitorTestFixtures!
    
    override func setUp() {
        super.setUp()
        self.fixtures = VisitorTestFixtures()
    }
    
    func testUpdateImportJobDocument() {
        let originalDocId = fixtures.document.id
        let newDocId = CompendiumSourceDocument.Id("newdoc")
        
        let sut = UpdateImportJobDocumentGameModelsVisitor(
            originalDocumentId: originalDocId, 
            updatedDocumentId: newDocId
        )
        
        var job = fixtures.importJob
        XCTAssertTrue(sut.visit(job: &job))
        XCTAssertEqual(job.documentId, newDocId)
        assertSnapshot(of: diff(fixtures.importJob, job) ?? "", as: .lines)
        
        // No changes on second visit
        XCTAssertFalse(sut.visit(job: &job))
        
        // Job with different document ID should not be changed
        var otherJob = CompendiumImportJob(
            sourceId: .init(type: "a", bookmark: "b"),
            sourceVersion: nil,
            documentId: .init("other"),
            timestamp: Date(timeIntervalSince1970: 0),
            uuid: UUID()
        )
        XCTAssertFalse(sut.visit(job: &otherJob))
    }
} 
