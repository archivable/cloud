import XCTest
import Combine
import Archivable

final class ClouderTests: XCTestCase {
    private var cloud: Cloud<Repository>.Stub!
    private var subs = Set<AnyCancellable>()

    override func setUp() {
        cloud = .init()
        cloud.archive.value = .new
    }
    
    func testAdd() {
        let expect = expectation(description: "")
        let date = Date()
        cloud.save.sink {
            XCTAssertGreaterThanOrEqual($0.date.timestamp, date.timestamp)
            expect.fulfill()
        }
        .store(in: &subs)
        var archive = Archive.new
        cloud.save(&archive)
        waitForExpectations(timeout: 1)
    }
}
