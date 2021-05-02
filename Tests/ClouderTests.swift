import XCTest
import Combine
import Archivable

final class ClouderTests: XCTestCase {
    private var cloud: Cloud<ArchiveMock>!
    private var subs = Set<AnyCancellable>()

    override func setUp() {
        cloud = .init(manifest: nil)
        cloud.archive.value = .new
    }
    
    func testMutateAndSave() {
        let expect = expectation(description: "")
        let date = Date()
        cloud.save.sink {
            XCTAssertEqual(Thread.main, Thread.current)
            XCTAssertGreaterThanOrEqual($0.date.timestamp, date.timestamp)
            XCTAssertGreaterThanOrEqual(self.cloud.archive.value.date.timestamp, date.timestamp)
            expect.fulfill()
        }
        .store(in: &subs)
        cloud.mutating {
            $0.date = .init()
        }
        waitForExpectations(timeout: 1)
    }
    
    func testMutateDontSave() {
        cloud.save.sink { _ in
            XCTFail()
        }
        .store(in: &subs)
        cloud.mutating { _ in }
    }
}
