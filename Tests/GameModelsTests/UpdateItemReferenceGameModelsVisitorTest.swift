import Foundation
import GameModels
import XCTest
import SnapshotTesting
import TestSupport
import Helpers
import CustomDump

final class UpdateItemReferenceGameModelsVisitorTest: XCTestCase {
    var fixtures: VisitorTestFixtures!
    
    override func setUp() {
        super.setUp()
        self.fixtures = VisitorTestFixtures()
    }
    
    func testUpdateItemReferences() {
        let originalKey = fixtures.entryInDocument1.item.key
        let updatedKey = CompendiumItemKey(
            type: originalKey.type,
            realm: .init("newrealm"),
            identifier: originalKey.identifier
        )
        
        let sut = UpdateItemReferenceGameModelsVisitor { key -> CompendiumItemKey? in
            if key == originalKey {
                return updatedKey
            }
            return nil
        }
        
        // Test CompendiumItemReference update
        var itemReference = CompendiumItemReference(
            itemTitle: "Reference to Item",
            itemKey: originalKey
        )
        XCTAssertTrue(sut.visit(itemReference: &itemReference))
        XCTAssertEqual(itemReference.itemKey, updatedKey)
        XCTAssertFalse(sut.visit(itemReference: &itemReference)) // No changes on second visit
        
        // Test CompendiumCombatantDefinition update
        var encounter = fixtures.encounter
        XCTAssertTrue(sut.visit(encounter: &encounter))
        
        let updatedCombatantKey = (encounter.combatants.first!.definition as! CompendiumCombatantDefinition).item.key
        XCTAssertEqual(updatedCombatantKey, updatedKey)
        XCTAssertFalse(sut.visit(encounter: &encounter)) // No changes on second visit
    }
} 