@testable import Construct
import TestSupport
import ViewInspector
import XCTest
import Persistence
import ComposableArchitecture

@MainActor
class SettingsViewTest: XCTestCase {

    func testTipJarVisible() async throws {
        let db = try! await Database(path: nil, source: Database(path: InitialDatabase.path))
        
        let store = Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.database = db
            $0.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
            $0.backgroundQueue = DispatchQueue.immediate.eraseToAnyScheduler()
        }
        let sut = SettingsView(store: store)
        XCTAssertNotNil(try sut.inspect().find(text: "Tip jar"))
    }

}
