import XCTest
@testable import Archivable

final class ArchTests: XCTestCase {
    private var archive: Archive!
    
    override func setUp() {
        archive = .init()
    }
    
    func testCompress() async {
        archive.counter = 99
        archive.timestamp = 123
        let parsed = await Archive(version: 3, timestamp: 123, data: archive.data)
        XCTAssertEqual(99, parsed.counter)
        XCTAssertEqual(123, parsed.timestamp)
    }
    
    func testVersion() {
        XCTAssertGreaterThanOrEqual(Archive.version, 3)
    }
}
