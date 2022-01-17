import XCTest
import Combine
@testable import Archivable

final class FlowTests: XCTestCase {
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() {
        cloud = .ephemeral
        subs = []
    }
    
    func testPersist() {
//        let expect = expectation(description: "")
//        let date = Date()
//        
//        cloud
//            .save
//            .sink {
//                XCTAssertEqual(1, $0.counter)
//                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
//                expect.fulfill()
//            }
//            .store(in: &subs)
//        
//        Task {
//            await cloud.increaseCounter()
//        }
//        
//        waitForExpectations(timeout: 1)
    }
}
