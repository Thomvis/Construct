import ComposableArchitecture
@testable import Construct
import Persistence
import XCTest

@MainActor
final class DefaultContentSelectionFeatureTest: XCTestCase {

    func testApplySelectionRequiresAtLeastOneEdition() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)

        let store = TestStore(initialState: DefaultContentSelectionFeature.State(selection: .none)) {
            DefaultContentSelectionFeature()
        } withDependencies: {
            $0.database = db
        }

        await store.send(.applySelection) {
            $0.error = .init(DefaultContentSelectionError.emptySelection)
        }
    }

    func testOnAppearLoadsDocumentStatus() async throws {
        let db = try await Database(path: nil)

        let store = TestStore(initialState: DefaultContentSelectionFeature.State(selection: .rules2014Only)) {
            DefaultContentSelectionFeature()
        } withDependencies: {
            $0.database = db
        }

        await store.send(.onAppear)
        await store.receive(.loadedStatusResponse(.success(Database.DefaultContentDocumentStatus(has2014Document: false, has2024Document: false))))
    }
}
