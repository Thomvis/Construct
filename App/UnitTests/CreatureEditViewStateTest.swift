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
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster)
        ) {
            CreatureEditFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
        }
        
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
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster, sourceDocument: customSource)
        ) {
            CreatureEditFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
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
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster)
        ) {
            CreatureEditFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
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
        let store = TestStore(
            initialState: CreatureEditFeature.State(create: .monster, sourceDocument: coreSource)
        ) {
            CreatureEditFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
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
    
    // MARK: - Test Dependencies
    private func applyTestDependencies(_ deps: inout DependencyValues) {
        deps.modifierFormatter = ModifierFormatter()
        deps.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
        deps.diceLog = DiceLogPublisher()
        deps.compendiumMetadata = CompendiumMetadata(
            sourceDocuments: { [.srd5_1, .homebrew] },
            observeSourceDocuments: { AsyncThrowingStream { _ in } },
            realms: { [CompendiumRealm.core, CompendiumRealm.homebrew] },
            observeRealms: { AsyncThrowingStream { _ in } },
            putJob: { _ in },
            createRealm: { _ in },
            updateRealm: { _, _ in },
            removeRealm: { _ in },
            createDocument: { _ in },
            updateDocument: { _, _ in },
            removeDocument: { _ in }
        )
        deps.mechMuse = MechMuse.unconfigured
        deps.database = Database.uninitialized
        deps.compendium = DatabaseCompendium(databaseAccess: deps.database.access)
        deps.uuid = UUIDGenerator.fake()
    }
}

class CompendiumMultiSourceFilterReducerTest: XCTestCase {
    @MainActor
    func testFilterSheetSourceSelectionStoresMultipleSources() async {
        let realmA = CompendiumRealm(id: "realm-a", displayName: "Realm A")
        let realmB = CompendiumRealm(id: "realm-b", displayName: "Realm B")
        let documentA = CompendiumSourceDocument(id: "doc-a", displayName: "Doc A", realmId: realmA.id)
        let documentB = CompendiumSourceDocument(id: "doc-b", displayName: "Doc B", realmId: realmB.id)

        let sourceA = CompendiumFilters.Source(documentA)
        let sourceB = CompendiumFilters.Source(documentB)

        let store = TestStore(initialState: CompendiumFilterSheetFeature.State()) {
            CompendiumFilterSheetFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
        }

        await store.send(.toggleDocumentSourceScope(sourceA)) {
            $0.current.sourceScopes = [.document(sourceA)]
        }

        await store.send(.toggleDocumentSourceScope(sourceB)) {
            $0.current.sourceScopes = [.document(sourceA), .document(sourceB)]
        }

        await store.send(.clear(.source)) {
            $0.current.sourceScopes = nil
        }
    }

    @MainActor
    func testFilterSheetRealmSelectionStoresRealmScopeAndClearsDocumentsInRealm() async {
        let realmA = CompendiumRealm(id: "realm-a", displayName: "Realm A")
        let documentA = CompendiumSourceDocument(id: "doc-a", displayName: "Doc A", realmId: realmA.id)
        let sourceA = CompendiumFilters.Source(documentA)

        let store = TestStore(initialState: CompendiumFilterSheetFeature.State()) {
            CompendiumFilterSheetFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
        }

        await store.send(.toggleDocumentSourceScope(sourceA)) {
            $0.current.sourceScopes = [.document(sourceA)]
        }

        await store.send(.toggleRealmSourceScope(realmA.id)) {
            $0.current.sourceScopes = [.realm(realmA.id)]
        }
    }

    @MainActor
    func testIndexAddUsesSingleSelectedSource() async {
        let source = CompendiumFilters.Source(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)

        let store = TestStore(
            initialState: apply(CompendiumIndexFeature.State(
                title: "Compendium",
                properties: .init(showImport: true, showAdd: true),
                results: .initial
            )) {
                $0.results.input.filters = .init(sourceScopes: [.document(source)])
            }
        ) {
            CompendiumIndexFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.onAddButtonTap(.monster))
        guard case let .creatureEdit(creatureEditState) = store.state.sheet else {
            return XCTFail("Expected creature edit sheet")
        }
        XCTAssertEqual(creatureEditState.model.document.selectedSource, source)
    }

    @MainActor
    func testIndexAddDefaultsToHomebrewWhenMultipleSourcesSelected() async {
        let sourceA = CompendiumFilters.Source(realm: CompendiumRealm.core.id, document: CompendiumSourceDocument.srd5_1.id)
        let sourceB = CompendiumFilters.Source(realm: CompendiumRealm.core2024.id, document: CompendiumSourceDocument.srd5_2.id)

        let store = TestStore(
            initialState: apply(CompendiumIndexFeature.State(
                title: "Compendium",
                properties: .init(showImport: true, showAdd: true),
                results: .initial
            )) {
                $0.results.input.filters = .init(sourceScopes: [.document(sourceA), .document(sourceB)])
            }
        ) {
            CompendiumIndexFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.onAddButtonTap(.monster))
        guard case let .creatureEdit(creatureEditState) = store.state.sheet else {
            return XCTFail("Expected creature edit sheet")
        }
        XCTAssertEqual(creatureEditState.model.document.selectedSource, .init(.homebrew))
    }

    @MainActor
    func testIndexApplyFilterSheetWritesSourcesToQueryFilters() async {
        let realmA = CompendiumRealm(id: "realm-a", displayName: "Realm A")
        let realmB = CompendiumRealm(id: "realm-b", displayName: "Realm B")
        let documentA = CompendiumSourceDocument(id: "doc-a", displayName: "Doc A", realmId: realmA.id)
        let documentB = CompendiumSourceDocument(id: "doc-b", displayName: "Doc B", realmId: realmB.id)
        let sourceA = CompendiumFilters.Source(documentA)
        let sourceB = CompendiumFilters.Source(documentB)
        let selectedSourceScopes: [CompendiumFilters.SourceScope] = [.document(sourceA), .document(sourceB)]

        let filterValues = CompendiumFilterSheetFeature.State.Values(
            sourceScopes: selectedSourceScopes,
            itemType: nil,
            minMonsterCR: nil,
            maxMonsterCR: nil,
            monsterType: nil
        )

        let store = TestStore(
            initialState: apply(CompendiumIndexFeature.State(
                title: "Compendium",
                properties: .init(showImport: true, showAdd: true),
                results: .initial
            )) {
                $0.sheet = .filter(CompendiumFilterSheetFeature.State(
                    initial: .init(),
                    current: filterValues
                ))
            }
        ) {
            CompendiumIndexFeature()
        } withDependencies: {
            applyTestDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.sheet(.presented(.filter(.onApply))))

        await store.receive(.results(.input(.onFiltersDidChange(.init(sourceScopes: selectedSourceScopes))))) {
            $0.results.input.filters = .init(sourceScopes: selectedSourceScopes)
        }
    }

    private func applyTestDependencies(_ deps: inout DependencyValues) {
        deps.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
        deps.compendiumMetadata = CompendiumMetadata(
            sourceDocuments: { [.srd5_1, .srd5_2, .homebrew] },
            observeSourceDocuments: { AsyncThrowingStream { _ in } },
            realms: { [CompendiumRealm.core, CompendiumRealm.core2024, CompendiumRealm.homebrew] },
            observeRealms: { AsyncThrowingStream { _ in } },
            putJob: { _ in },
            createRealm: { _ in },
            updateRealm: { _, _ in },
            removeRealm: { _ in },
            createDocument: { _ in },
            updateDocument: { _, _ in },
            removeDocument: { _ in }
        )
        deps.database = Database.uninitialized
        deps.compendium = DatabaseCompendium(databaseAccess: deps.database.access)
        deps.uuid = UUIDGenerator.fake()
    }
}
