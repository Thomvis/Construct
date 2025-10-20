@testable import Construct
import TestSupport
import ViewInspector
import XCTest
import Persistence

@MainActor
class SettingsViewTest: XCTestCase {

    func testTipJarVisible() async throws {
        let db = try! await Database(path: nil, source: Database(path: InitialDatabase.path))
        let env = try! await Environment.live(
            database: db,
            mainQueue: DispatchQueue.immediate.eraseToAnyScheduler(),
            backgroundQueue: DispatchQueue.immediate.eraseToAnyScheduler()
        )

        let sut = SettingsView()
            .environmentObject(env)

        XCTAssertNotNil(try sut.inspect().find(text: "Tip jar"))
    }

}
