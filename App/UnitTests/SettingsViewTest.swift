@testable import Construct
import TestSupport
import ViewInspector
import XCTest
import Persistence

@MainActor
class SettingsViewTest: XCTestCase {

    func testTipJarVisible() async throws {
        let db = try! await Database(path: nil, source: Database(path: InitialDatabase.path))
        
        try await withDependencies {
            $0.database = db
            $0.mainQueue = DispatchQueue.immediate.eraseToAnyScheduler()
            $0.backgroundQueue = DispatchQueue.immediate.eraseToAnyScheduler()
        } operation: {
            let sut = SettingsView()
            XCTAssertNotNil(try sut.inspect().find(text: "Tip jar"))
        }
    }

}
