import ComposableArchitecture
@testable import Construct
import Persistence
import TestSupport
import XCTest

@MainActor
final class AppDefaultContentSelectionTest: XCTestCase {

    func testWelcomeDefaultContentSkipShowsConfirmationBeforeDismissing() async {
        let store = TestStore(initialState: WelcomeFeature.State()) {
            WelcomeFeature()
        }
        store.exhaustivity = .off

        await store.send(.didTapSkip)
        XCTAssertNotNil(store.state.alert)

        await store.send(.alert(.presented(.confirmSkip))) {
            $0.alert = nil
        }
        await store.receive(.delegate(.dismissWelcomeSheet))
    }

    func testOnAppearPresentsWelcomeForNewUsersWithEmptySelection() async throws {
        let db = try await Database(path: nil, importDefaultContent: false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.database = db
            $0.idleTimer = .init(setIdleTimerDisabled: { _ in })
            $0.uuid = UUIDGenerator.fake()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.requestDestination(.welcome(.init()))) {
            $0.destination = .welcome(.init())
        }
        XCTAssertEqual(store.state.preferences.didShowWelcomeSheet, false)

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
        XCTAssertEqual(store.state.preferences.didShowWelcomeSheet, true)
    }
}
