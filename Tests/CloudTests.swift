import XCTest
import Combine
@testable import Archivable

final class CloudTests: XCTestCase {
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() {
        cloud = .emphemeral
        subs = []
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
        
        await cloud.increaseCounter()
        await waitForExpectations(timeout: 1)
    }
    
    func testStream() async {
        let expect = expectation(description: "")
        let date = Date()
        cloud
            .archive
            .dropFirst()
            .sink {
                XCTAssertEqual(1, $0.counter)
                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        await cloud.increaseCounter()
        await waitForExpectations(timeout: 1)
    }
    
    func testSubscription() {
        let expect = expectation(description: "")
        
        _ = cloud
            .dropFirst()
            .sink { _ in
                XCTFail()
            }
        
        cloud
            .first()
            .sink {
                XCTAssertEqual(0, $0.counter)
                Task {
                    await self.cloud.increaseCounter()
                }
            }
            .store(in: &subs)
        
        var sub1: AnyCancellable?
        sub1 = cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(1, $0.counter)
                sub1?.cancel()
                Task {
                    await self.cloud.increaseCounter()
                }
            }
        
        var sub2: AnyCancellable?
        sub2 = cloud
            .dropFirst(2)
            .sink {
                XCTAssertEqual(2, $0.counter)
                sub2 = nil
                XCTAssertNil(sub2)
                Task {
                    await self.cloud.increaseCounter()
                    let count = await self.cloud.attachments.count
                    XCTAssertEqual(0, count)
                    expect.fulfill()
                }
            }
        
        waitForExpectations(timeout: 1)
    }
}
