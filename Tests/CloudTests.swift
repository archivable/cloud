import XCTest
import Combine
@testable import Cloud

final class CloudTests: XCTestCase {
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() {
        cloud = .init()
        subs = []
        
        try? FileManager.default.removeItem(at: cloud.url)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: cloud.url)
    }
    
    func testPersist() {
        let expect = expectation(description: "")
        let date = Date()
        
        cloud
            .store
            .sink {
                XCTAssertEqual(1, $0.0.counter)
                XCTAssertGreaterThanOrEqual($0.0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        Task {
            var model = await cloud.model
            model.counter += 1
            await cloud.update(model: model)
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testSubscribe() {
        let expect = expectation(description: "")

        cloud
            .sink { _ in
                XCTAssertEqual(Thread.main, Thread.current)
                expect.fulfill()
            }
            .store(in: &subs)
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testLoadedNotRepeat() {
        let expect = expectation(description: "")

        cloud
            .sink { _ in
                XCTAssertEqual(Thread.main, Thread.current)
                expect.fulfill()
            }
            .store(in: &subs)
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testStream() {
        let expect = expectation(description: "")
        let date = Date()
        
        cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(Thread.main, Thread.current)
                XCTAssertEqual(1, $0.counter)
                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        Task {
            var model = await cloud.model
            model.counter += 1
            await cloud.update(model: model)
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testSubscription() {
        let expect = expectation(description: "")
        let inversed = expectation(description: "")
        inversed.isInverted = true
        
        _ = cloud
            .dropFirst()
            .sink { _ in
                inversed.fulfill()
            }
        
        cloud
            .first()
            .sink {
                XCTAssertEqual(0, $0.counter)
                Task {
                    var model = await self.cloud.model
                    model.counter += 1
                    await self.cloud.update(model: model)
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
                    var model = await self.cloud.model
                    model.counter += 1
                    await self.cloud.update(model: model)
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
                    var model = await self.cloud.model
                    model.counter += 1
                    await self.cloud.update(model: model)
                    let count = await self.cloud.actor.contracts.count
                    XCTAssertEqual(0, count)
                    expect.fulfill()
                }
            }
        
        waitForExpectations(timeout: 0.5)
    }
}
