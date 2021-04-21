import XCTest
import Archivable

final class Tests: XCTestCase {
    func testNumbers() {
        Data()
            .adding(UInt8(1))
            .adding(UInt16(2))
            .adding(UInt32(3))
            .adding(UInt64(4))
            .adding(true)
            .adding(false)
            .compressed
            .mutating {
                $0.decompress()
                XCTAssertEqual(1, $0.removeFirst())
                XCTAssertEqual(2, $0.uInt16())
                XCTAssertEqual(3, $0.uInt32())
                XCTAssertEqual(4, $0.uInt64())
                XCTAssertEqual(true, $0.bool())
                XCTAssertEqual(false, $0.bool())
            }
    }
}
