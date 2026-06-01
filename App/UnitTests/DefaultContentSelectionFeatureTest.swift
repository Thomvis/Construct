import Compendium
import ComposableArchitecture
@testable import Construct
import GameModels
import Persistence
import TestSupport
import XCTest

@MainActor
final class DefaultContentSelectionFeatureTest: XCTestCase {

    func testApplySelectionRequiresAtLeastOneEdition() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)
        let initialState = withDependencies {
            $0.uuid = UUIDGenerator.fake()
        } operation: {
            DefaultContentSelectionFeature.State()
        }

        let store = TestStore(initialState: initialState) {
            DefaultContentSelectionFeature()
        } withDependencies: {
            $0.database = db
            $0.uuid = UUIDGenerator.fake()
        }

        await store.send(.applySelection) {
            $0.applySelection.result = .failure(.init(DefaultContentSelectionError.emptySelection))
        }
    }

    func testApplySelectionAllowsSampleEncounterOnlyWhenConfigured() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)
        let initialState = withDependencies {
            $0.uuid = UUIDGenerator.fake()
        } operation: {
            DefaultContentSelectionFeature.State(
                restoreSampleEncounter: true,
                allowsSampleEncounterOnly: true
            )
        }

        let store = TestStore(initialState: initialState) {
            DefaultContentSelectionFeature()
        } withDependencies: {
            $0.database = db
            $0.uuid = UUIDGenerator.fake()
        }

        await store.send(.applySelection)
        await store.receive(.delegate(.applied(.init(
            selection: [],
            restoreSampleEncounter: true
        ))))
    }

    func testOnAppearLoadsDocumentStatus() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)
        try db.keyValueStore.put(CompendiumImportJob(
            sourceId: .defaultMonsters2014,
            sourceVersion: DefaultContentSource.monsters2014.currentVersion,
            documentId: CompendiumSourceDocument.srd5_1.id
        ))

        var initialState = withDependencies {
            $0.uuid = UUIDGenerator.fake()
        } operation: {
            DefaultContentSelectionFeature.State()
        }
        initialState.selection = [.rules2014]

        let store = TestStore(initialState: initialState) {
            DefaultContentSelectionFeature()
        } withDependencies: {
            $0.compendium = DatabaseCompendium(databaseAccess: db.access)
            $0.compendiumMetadata = .live(db)
            $0.database = db
            $0.uuid = UUIDGenerator.fake()
        }

        await store.send(.onAppear)
        await store.receive(.importedDefaultContentVersions(.startLoading))
        await store.receive(.importedDefaultContentVersions(.didStartLoading)) {
            $0.importedDefaultContentVersions.isLoading = true
            $0.importedDefaultContentVersions.result = nil
        }
        let versions = DefaultContentVersions(versions: [
            .monsters2014: DefaultContentSource.monsters2014.currentVersion
        ])
        await store.receive(.importedDefaultContentVersions(.didFinishLoading(.success(versions)))) {
            $0.importedDefaultContentVersions.isLoading = false
            $0.importedDefaultContentVersions.result = .success(versions)
        }
    }
}
