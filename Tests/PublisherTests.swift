import XCTest
import Combine
@testable import Cloud

final class PublisherTests: XCTestCase {
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() {
        cloud = .init()
        subs = []
    }
    
    func testOneSubscriber() {
        let expect = expectation(description: "")
        
        cloud
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testTwoSubscribers() {
        let expect = expectation(description: "")
        expect.expectedFulfillmentCount = 2
        
        cloud
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testUpdate() {
        let expect = expectation(description: "")
        expect.expectedFulfillmentCount = 3
        
        cloud
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        Task {
            var model = await cloud.model
            model.counter += 1
            await cloud.update(model: model)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.cloud
                .sink { _ in
                    expect.fulfill()
                }
                .store(in: &self.subs)
        }
        
        waitForExpectations(timeout: 0.5)
    }
}
