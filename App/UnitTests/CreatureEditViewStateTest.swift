//
//  CreatureEditViewStateTest.swift
//  UnitTests
//
//  Created by Thomas Visser on 17/06/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
@testable import Construct
import GameModels
import Compendium
import ComposableArchitecture
import Helpers
import DiceRollerFeature
import MechMuse
import Persistence

class CreatureEditViewStateTest: XCTestCase {
    
    @MainActor
    func testNewMonsterDefaultsToHomebrew() async {
        let testEnv = TestEnvironment()
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster),
            reducer: CreatureEditFeature()
        ) {
            $0.modifierFormatter = testEnv.modifierFormatter
            $0.mainQueue = testEnv.mainQueue
            $0.diceLog = testEnv.diceLog
            $0.compendiumMetadata = testEnv.compendiumMetadata
            $0.mechMuse = testEnv.mechMuse
            $0.compendium = testEnv.compendium
            $0.database = testEnv.database
        }
        
        // Verify initial document selection is nil (allowing all sources)
        XCTAssertNil(store.state.model.document.selectedSource)
        
        // Set required fields to make monster valid
        var updatedModel = store.state.model
        updatedModel.statBlock.name = "Test Monster"
        updatedModel.statBlock.challengeRating = Fraction(integer: 1)

        await store.send(.model(updatedModel)) {
            $0.model.statBlock.name = "Test Monster"
            $0.model.statBlock.challengeRating = Fraction(integer: 1)
        }
        
        // Get the created monster - should default to homebrew realm since no source was selected
        guard let monster = store.state.monster else {
            XCTFail("Monster should be valid with name and CR set")
            return
        }
        XCTAssertEqual(monster.realm.value, CompendiumRealm.homebrew.id)
    }
    
    @MainActor
    func testNewMonsterWithCustomSource() async {
        // Test that creating a new monster with a custom source uses that source
        let customSource = CompendiumFilters.Source(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)
        let testEnv = TestEnvironment()
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster, sourceDocument: customSource),
            reducer: CreatureEditFeature()
        ) {
            $0.modifierFormatter = testEnv.modifierFormatter
            $0.mainQueue = testEnv.mainQueue
            $0.diceLog = testEnv.diceLog
            $0.compendiumMetadata = testEnv.compendiumMetadata
            $0.mechMuse = testEnv.mechMuse
            $0.compendium = testEnv.compendium
            $0.database = testEnv.database
        }
        
        // Verify initial document selection is set
        XCTAssertEqual(store.state.model.document.selectedSource, customSource)
        
        // Set required fields to make monster valid
        var updatedModel = store.state.model
        updatedModel.statBlock.name = "Test Monster"
        updatedModel.statBlock.challengeRating = Fraction(integer: 1)

        await store.send(.model(updatedModel)) {
            $0.model.statBlock.name = "Test Monster"
            $0.model.statBlock.challengeRating = Fraction(integer: 1)
        }
        
        // Should use the selected source's realm
        guard let monster = store.state.monster else {
            XCTFail("Monster should be valid with name and CR set")
            return
        }
        XCTAssertEqual(monster.realm.value, CompendiumRealm.core.id)
    }
    
    @MainActor
    func testDocumentSelectionUpdatesOutput() async {
        let testEnv = TestEnvironment()
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster),
            reducer: CreatureEditFeature()
        ) {
            $0.modifierFormatter = testEnv.modifierFormatter
            $0.mainQueue = testEnv.mainQueue
            $0.diceLog = testEnv.diceLog
            $0.compendiumMetadata = testEnv.compendiumMetadata
            $0.mechMuse = testEnv.mechMuse
            $0.compendium = testEnv.compendium
            $0.database = testEnv.database
        }
        
        // Set required fields to make monster valid
        var updatedModel = store.state.model
        updatedModel.statBlock.name = "Test Monster"
        updatedModel.statBlock.challengeRating = Fraction(integer: 1)

        await store.send(.model(updatedModel)) {
            $0.model.statBlock.name = "Test Monster"
            $0.model.statBlock.challengeRating = Fraction(integer: 1)
        }
        
        // Initially should default to homebrew
        guard let initialMonster = store.state.monster else {
            XCTFail("Monster should be valid")
            return
        }
        XCTAssertEqual(initialMonster.realm.value, CompendiumRealm.homebrew.id)
        
        // Simulate user selecting a different document via the document selection feature
        let coreDocument = CompendiumSourceDocument.srd5_1
        let coreRealm = CompendiumRealm(id: CompendiumRealm.core.id, displayName: "Core")
        
        await store.send(.documentSelection(.source(coreDocument, coreRealm))) {
            $0.model.document.selectedSource = CompendiumFilters.Source(coreDocument)
        }
        
        // Output should now use core realm
        guard let updatedMonster = store.state.monster else {
            XCTFail("Monster should still be valid")
            return
        }
        XCTAssertEqual(updatedMonster.realm.value, CompendiumRealm.core.id)
        XCTAssertEqual(updatedMonster.stats.name, "Test Monster") // Other properties preserved
        XCTAssertEqual(updatedMonster.challengeRating, Fraction(integer: 1))
    }
    
    @MainActor
    func testClearingDocumentSelectionDefaultsToHomebrew() async {
        // Start with a core document selected
        let coreSource = CompendiumFilters.Source(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)
        let testEnv = TestEnvironment()
        let store = TestStore(
            initialState: CreatureEditViewState(create: .monster, sourceDocument: coreSource),
            reducer: CreatureEditFeature()
        ) {
            $0.modifierFormatter = testEnv.modifierFormatter
            $0.mainQueue = testEnv.mainQueue
            $0.diceLog = testEnv.diceLog
            $0.compendiumMetadata = testEnv.compendiumMetadata
            $0.mechMuse = testEnv.mechMuse
            $0.compendium = testEnv.compendium
            $0.database = testEnv.database
        }
        
        // Set required fields
        var updatedModel = store.state.model
        updatedModel.statBlock.name = "Test Monster"
        updatedModel.statBlock.challengeRating = Fraction(integer: 1)

        await store.send(.model(updatedModel)) {
            $0.model.statBlock.name = "Test Monster"
            $0.model.statBlock.challengeRating = Fraction(integer: 1)
        }
        
        // Should initially use core realm
        XCTAssertEqual(store.state.monster?.realm.value, CompendiumRealm.core.id)
        
        // Clear the document selection
        await store.send(.documentSelection(.clearSource)) {
            $0.model.document.selectedSource = nil
        }
        
        // Should now default back to homebrew
        guard let monster = store.state.monster else {
            XCTFail("Monster should still be valid")
            return
        }
        XCTAssertEqual(monster.realm.value, CompendiumRealm.homebrew.id)
    }
    
    func testEditMonsterPreservesDocumentSelection() {
        // Test that editing a monster from core realm shows the correct document selection
        let coreMonster = Monster(
            realm: .init(CompendiumRealm.core.id), 
            stats: StatBlock(name: "Ancient Dragon"), 
            challengeRating: Fraction(integer: 20)
        )
        
        let sut = CreatureEditFeature.State(edit: coreMonster, documentId: CompendiumSourceDocument.srd5_1.id)
        
        // Should have the correct document selection based on realm and provided document ID
        let expectedSource = CompendiumFilters.Source(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)
        XCTAssertEqual(sut.model.document.selectedSource, expectedSource)
        
        // Output should preserve the realm
        guard let editedMonster = sut.monster else {
            XCTFail("Monster should be valid")
            return
        }
        XCTAssertEqual(editedMonster.realm.value, CompendiumRealm.core.id)
    }
    
    // MARK: - Test Environment
    
    class TestEnvironment: EnvironmentWithModifierFormatter & EnvironmentWithMainQueue & EnvironmentWithDiceLog & EnvironmentWithCompendiumMetadata & EnvironmentWithMechMuse & EnvironmentWithCompendium & EnvironmentWithDatabase {
        var modifierFormatter: NumberFormatter = Helpers.modifierFormatter
        var mainQueue: AnySchedulerOf<DispatchQueue> = DispatchQueue.immediate.eraseToAnyScheduler()
        var diceLog: DiceLogPublisher = DiceLogPublisher()
        var compendiumMetadata: CompendiumMetadata = CompendiumMetadata(
            sourceDocuments: { [.srd5_1, .homebrew] },
            observeSourceDocuments: { AsyncThrowingStream { _ in } },
            realms: { [CompendiumRealm.core, CompendiumRealm.homebrew] },
            observeRealms: { AsyncThrowingStream { _ in } },
            putJob: { _ in },
            createRealm: { _ in },
            updateRealm: { _, _ in },
            removeRealm: { _ in },
            createDocument: { _ in },
            updateDocument: { _, _, _ in },
            removeDocument: { _, _ in }
        )
        var mechMuse: MechMuse = MechMuse.unconfigured
        var database: Database = Database.uninitialized
        var compendium: Compendium { DatabaseCompendium(databaseAccess: database.access) }
    }
}
