import XCTest
import Combine
import CloudKit
@testable import Archivable

final class FlowTests: XCTestCase {
    private var container: ContainerMock!
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    private var remote: URL!
    
    override func setUp() async throws {
        container = .init()
        cloud = .init()
        try? FileManager.default.removeItem(at: cloud.url)
        await cloud.load(container: container)
        subs = []
        
        remote = .init(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try! await Archive(timestamp: 99, counter: 22).compressed.write(to: remote)
    }
    
    override func tearDown() {
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
    
    func testLocalMergeRemoteMergeSave_Local() {
        let expect = expectation(description: "")
        
        cloud.remote.send(.init(timestamp: 1))
        cloud.save.send(.init(timestamp: 2))
        
        cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(3, $0.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.local.send(.init(timestamp: 3))
        
        waitForExpectations(timeout: 1)
    }
    
    func testLocalMergeRemoteMergeSave_Remote() {
        let expect = expectation(description: "")
        
        cloud.local.send(.init(timestamp: 1))
        
        cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(2, $0.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.remote.send(.init(timestamp: 2))
        
        waitForExpectations(timeout: 1)
    }
    
    func testLocalMergeRemoteMergeSave_Save() {
        cloud.save.send(.init(timestamp: 3))
        cloud
            .dropFirst()
            .sink { _ in
                XCTFail()
            }
            .store(in: &subs)
        
        cloud.remote.send(.init(timestamp: 2))
    }
    
    func testRecordCombinePull() {
        let expect = expectation(description: "")
        
        let asset = CKAsset(fileURL: remote)
        let record = CKRecord(recordType: "lorem")
        record["payload"] = asset
        (container.database as! DatabaseMock).record = record
        
        cloud
            .remote
            .sink {
                XCTAssertEqual(99, $0?.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.record.send(.init(recordName: "lorem"))
        cloud.pull.send()
        
        waitForExpectations(timeout: 1)
    }
}
