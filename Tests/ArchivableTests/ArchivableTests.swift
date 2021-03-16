import XCTest
@testable import Archivable

final class ArchivableTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Archivable().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
