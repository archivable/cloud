import XCTest
import Combine
@testable import Archivable

final class CloudTests: XCTestCase {
    private var cloud: Cloud<ArchiveMock>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        Task {
            cloud = await .init(container: nil)
            completion(nil)
        }
        subs = .init()
    }
    
    func testPersist() async {
        let expect = expectation(description: "")
        let date = Date()
        cloud
            .save
            .sink {
                XCTAssertEqual(1, $0.counter)
                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        await cloud.increaseCounterPersist()
        await waitForExpectations(timeout: 1)
    }
    
    func testStream() async {
        let expect = expectation(description: "")
        let date = Date()
        cloud
            .archive
            .sink {
                XCTAssertEqual(1, $0.counter)
                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        await cloud.increaseCounterStream()
        await waitForExpectations(timeout: 1)
    }
}
