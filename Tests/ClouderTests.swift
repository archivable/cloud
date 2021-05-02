import XCTest
import Combine
import Archivable

final class ClouderTests: XCTestCase {
    private var cloud: Cloud<ArchiveMock>!
    private var subs = Set<AnyCancellable>()

    override func setUp() {
        cloud = .init(manifest: nil)
    }
    
    func testMutateAndArchive() {
        let expect = expectation(description: "")
        let date = Date()
        cloud
            .archive
            .dropFirst()
            .sink {
                XCTAssertTrue(Thread.current.isMainThread)
                XCTAssertGreaterThanOrEqual($0.date.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.mutating {
            $0.date = .init(timeIntervalSince1970: 10)
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testMutateAndSave() {
        let expect = expectation(description: "")
        let date = Date()
        cloud.save.sink {
            XCTAssertGreaterThanOrEqual($0.date.timestamp, date.timestamp)
            expect.fulfill()
        }
        .store(in: &subs)
        
        cloud.mutating {
            $0.date = .init(timeIntervalSince1970: 10)
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
    
    func testReceipt() {
        let expect = expectation(description: "")
        cloud.receipt {
            XCTAssertTrue($0)
            expect.fulfill()
        }
        
        cloud.mutating {
            $0.date = .init(timeIntervalSince1970: 10)
        }
        
        waitForExpectations(timeout: 1)
    }
}
