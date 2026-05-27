import ComposableArchitecture
@testable import Construct
import Persistence
import TestSupport
import XCTest

@MainActor
final class DefaultContentSelectionFeatureTest: XCTestCase {

    func testApplySelectionRequiresAtLeastOneEdition() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)

        let store = TestStore(initialState: DefaultContentSelectionFeature.State(selection: [])) {
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

        let store = TestStore(initialState: DefaultContentSelectionFeature.State(
            selection: [],
            restoreSampleEncounter: true,
            allowsSampleEncounterOnly: true
        )) {
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
        let db = try await Database(path: nil)

        let store = TestStore(initialState: DefaultContentSelectionFeature.State(selection: [.rules2014])) {
            DefaultContentSelectionFeature()
        } withDependencies: {
            $0.database = db
            $0.uuid = UUIDGenerator.fake()
        }

        await store.send(.onAppear)
        await store.receive(.defaultDocumentStatus(.startLoading))
        await store.receive(.defaultDocumentStatus(.didStartLoading)) {
            $0.defaultDocumentStatus.isLoading = true
            $0.defaultDocumentStatus.result = nil
        }
        await store.receive(.defaultDocumentStatus(.didFinishLoading(.success(
            Database.DefaultContentDocumentStatus(
                importedRulesets: [],
                newRulesets: [.rules2014, .rules2024],
                updatedRulesets: []
            )
        )))) {
            $0.defaultDocumentStatus.isLoading = false
            $0.defaultDocumentStatus.result = .success(
                Database.DefaultContentDocumentStatus(
                    importedRulesets: [],
                    newRulesets: [.rules2014, .rules2024],
                    updatedRulesets: []
                )
            )
        }
    }
}
