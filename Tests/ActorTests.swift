import XCTest
@testable import Archivable

final class ActorTests: XCTestCase {
    func testInit() async {
        let act = await Actor()
        let n = await act.number
        XCTAssertEqual(1, n)
    }
}
