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
        try? FileManager.default.removeItem(at: cloud.url)
        await cloud.load(container: container)
        subs = []
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cloud.url)
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
    
    func testPullMergePush_NotAvailable() {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        cloud
            .record
            .sink { _ in
                expect.fulfill()
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
        
        waitForExpectations(timeout: 1)
    }
    
    func testPullMergePush_Available_Pull() {
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
    
    func testPullMergePush_Available_Push() {
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
    
    func testLocalMergeRemote_Local() {
        let expect = expectation(description: "")

        cloud
            .dropFirst()
            .sink { received in
                Task {
                    let current = await self.cloud.model.timestamp
                    XCTAssertEqual(2, current)
                    XCTAssertEqual(2, received.timestamp)
                    expect.fulfill()
                }
            }
            .store(in: &subs)
        
        cloud.local.send(.init(timestamp: 2))
        
        waitForExpectations(timeout: 1)
    }
    
    func testLocalMergeRemote_Remote() {
        let expect = expectation(description: "")
        
        cloud
            .dropFirst()
            .sink { received in
                Task {
                    let current = await self.cloud.model.timestamp
                    XCTAssertEqual(2, current)
                    XCTAssertEqual(2, received.timestamp)
                    expect.fulfill()
                }
            }
            .store(in: &subs)
        
        cloud.remote.send(.init(timestamp: 2))
        
        waitForExpectations(timeout: 1)
    }
    
    func testRecordCombinePush() {
        let expect = expectation(description: "")
        
        cloud.record.send(.init(recordName: "lorem"))
        
        (container.database as! DatabaseMock).pushed
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.push.send()
        
        waitForExpectations(timeout: 1)
    }
    
    func testLocalMergeSaveCombineRemote_Remote() {
        let expect = expectation(description: "")
        
        cloud.local.send(.init(timestamp: 1))
        cloud.save.send(.init(timestamp: 2))
        
        cloud
            .store
            .sink {
                XCTAssertFalse($0.1)
                XCTAssertEqual(3, $0.0.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.remote.send(.init(timestamp: 3))
        
        waitForExpectations(timeout: 1)
    }
    
    func testLocalMergeSaveCombineRemote_Local() {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        cloud.local.send(.init(timestamp: 3))
        
        cloud
            .store
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.remote.send(.init(timestamp: 2))
        
        waitForExpectations(timeout: 1)
    }
    
    func testRemoteCombineLocalMergeSave_RemoteNil() {
        let expect = expectation(description: "")
        
        cloud.remote.send(nil)
        
        cloud
            .push
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.local.send(.init(timestamp: 2))
        
        waitForExpectations(timeout: 1)
    }
    
    func testRemoteCombineLocalMergeSave_Local() {
        let expect = expectation(description: "")
        
        cloud.remote.send(.init(timestamp: 4))
        
        cloud
            .push
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.local.send(.init(timestamp: 5))
        
        waitForExpectations(timeout: 1)
    }
    
    func testRemoteCombineLocalMergeSave_Duplicate() {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        cloud.remote.send(nil)
        cloud.local.send(.init(timestamp: 1))
        
        cloud
            .push
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.local.send(.init(timestamp: 1))
        
        waitForExpectations(timeout: 1)
    }
    
    func testRemoteCombineLocalMergeSave_Remote() {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        cloud.remote.send(.init(timestamp: 3))
        
        cloud
            .push
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.local.send(.init(timestamp: 2))
        
        waitForExpectations(timeout: 1)
    }
    
    func testStore() {
        let expect = expectation(description: "")
        
        cloud
            .push
            .sink {
                let file = try! Data(contentsOf: self.cloud.url)
                XCTAssertFalse(file.isEmpty)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.store.send((.init(timestamp: 1), true))
        
        waitForExpectations(timeout: 1)
    }
    
    func testStore_NoPush() {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        cloud.remote.send(.init(timestamp: 3))
        
        cloud
            .push
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.store.send((.init(timestamp: 1), false))
        
        waitForExpectations(timeout: 1)
    }
    
    func testPull_Throttle() {
        let expect = expectation(description: "")
        
        cloud.record.send(.init(recordName: "lorem"))
        
        (container.database as! DatabaseMock).pulled
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.pull.send()
        cloud.pull.send()
        cloud.pull.send()
        
        waitForExpectations(timeout: 1)
    }
}
