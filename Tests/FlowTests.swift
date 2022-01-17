import XCTest
import Combine
import CloudKit
@testable import Archivable

final class FlowTests: XCTestCase {
    private var container: ContainerMock!
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() async throws {
        container = .init()
        cloud = .init()
        await cloud.load(container: container)
        subs = []
    }
    
    func testSubscription() {
        let expect = expectation(description: "")
        
        (container.database as! DatabaseMock)
            .saved
            .sink {
                let query = $0 as? CKQuerySubscription
                XCTAssertNotNil(query)
                XCTAssertTrue(query!.predicate.predicateFormat.hasSuffix("; recordName=lorem, zoneID=_defaultZone:__defaultOwner__>"))
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.record.send(.init(recordName: "lorem"))
        
        waitForExpectations(timeout: 1)
    }
    
    func testPullMergePushNotAvailable() {
        cloud
            .record
            .sink { _ in
                XCTFail()
            }
            .store(in: &subs)
        
        container.status = .noAccount
        cloud.pull.send()
        cloud.push.send()

        container.status = .couldNotDetermine
        cloud.pull.send()
        cloud.push.send()

        container.status = .restricted
        cloud.pull.send()
        cloud.push.send()

        container.status = .temporarilyUnavailable
        cloud.pull.send()
        cloud.push.send()
    }
    
    func testPullMergePushAvailablePull() {
        let expect = expectation(description: "")
        
        cloud
            .record
            .sink {
                XCTAssertEqual("ilorem", $0.recordName)
                expect.fulfill()
            }
            .store(in: &subs)
        
        container.status = .available
        cloud.pull.send()
        
        waitForExpectations(timeout: 1)
    }
    
    func testPullMergePushAvailablePush() {
        let expect = expectation(description: "")
        
        cloud
            .record
            .sink {
                XCTAssertEqual("ilorem", $0.recordName)
                expect.fulfill()
            }
            .store(in: &subs)
        
        container.status = .available
        cloud.push.send()
        
        waitForExpectations(timeout: 1)
    }
    
    func testLocalMergeRemote() {
        let expect = expectation(description: "")
        
        cloud
            .record
            .sink {
                XCTAssertEqual("ilorem", $0.recordName)
                expect.fulfill()
            }
            .store(in: &subs)
        
        container.status = .available
        cloud.push.send()
        
        waitForExpectations(timeout: 1)
    }
}
