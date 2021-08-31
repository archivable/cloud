import XCTest
@testable import Archivable

final class ArchTests: XCTestCase {
    private var archive: Archive!
    
    override func setUp() {
        archive = .new
    }
    
    func testCompress() async {
        archive.counter = 99
        archive.timestamp = 123
        let parsed = await Archive.prototype(data: archive.compressed)
        XCTAssertEqual(99, parsed.counter)
        XCTAssertEqual(123, parsed.timestamp)
    }
    
    func testVersion() async {
        let version = await archive.compressed.decompress.first
        XCTAssertEqual(128, version)
    }
}
