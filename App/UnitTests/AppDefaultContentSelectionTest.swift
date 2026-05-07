import ComposableArchitecture
@testable import Construct
import Persistence
import XCTest

@MainActor
final class AppDefaultContentSelectionTest: XCTestCase {

    func testOnAppearPresentsWelcomeForNewUsersWithEmptySelection() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.database = db
            $0.idleTimer = .init(isIdleTimerDisabled: .constant(false))
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.requestDestination(.welcome(.init(selection: .none, sampleEncounterDefault: true)))) {
            $0.destination = .welcome(.init(selection: .none, sampleEncounterDefault: true))
        }
    }

    func testOnAppearPresentsSelectionSheetForExistingUsersWithoutPersistedSelection() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.database = db
            $0.idleTimer = .init(isIdleTimerDisabled: .constant(false))
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.requestDestination(.welcome(.init(selection: .none, sampleEncounterDefault: true)))) {
            $0.destination = .welcome(.init(selection: .none, sampleEncounterDefault: true))
        }

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }

        await store.send(.onAppear)
        await store.receive(.requestDestination(.defaultContentSelection(
            .init(
                selection: .rules2014Only,
                sampleEncounterOption: .init(
                    title: "Load sample encounter",
                    isEnabled: true
                )
            )
        ))) {
            $0.destination = .defaultContentSelection(
                .init(
                    selection: .rules2014Only,
                    sampleEncounterOption: .init(
                        title: "Load sample encounter",
                        isEnabled: true
                    )
                )
            )
        }
    }
}
