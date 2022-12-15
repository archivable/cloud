import XCTest
import Combine
import CloudKit
@testable import Cloud

final class ReadyTests: XCTestCase {
    private var container: MockContainer!
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() async throws {
        container = .init(identifier: "")
        cloud = .init()
        try? FileManager.default.removeItem(at: cloud.url)
        subs = []
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cloud.url)
    }
    
    func testOnlyOnce() {
        let expect = expectation(description: "")
        let remote = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let asset = CKAsset(fileURL: remote)
        let record = CKRecord(recordType: "lorem")
        record["payload"] = asset
        container.database.record = record
        container.status = .available
        
        cloud
            .ready
            .notify(queue: .main) {
                expect.fulfill()
            }
        
        Task {
            try! await Wrapper(archive: Archive(timestamp: 99, counter: 22)).compressed.write(to: remote)
            
            await cloud.load(container: container)
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testNoAccount() {
        let expect = expectation(description: "")
        container.status = .noAccount
        
        cloud
            .ready
            .notify(queue: .main) {
                expect.fulfill()
            }
        
        Task {
            await cloud.load(container: container)
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testNoRemote() {
        let expect = expectation(description: "")
        container.status = .available
        
        cloud
            .ready
            .notify(queue: .main) {
                expect.fulfill()
            }
        
        Task {
            await cloud.load(container: container)
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testRemoteSmallerThanLocal() {
        let expect = expectation(description: "")
        let remote = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let asset = CKAsset(fileURL: remote)
        let record = CKRecord(recordType: "lorem")
        record["payload"] = asset
        container.database.record = record
        container.status = .available
        
        cloud
            .ready
            .notify(queue: .main) {
                expect.fulfill()
            }
        
        Task {
            try! await Wrapper(archive: Archive(timestamp: 2)).compressed.write(to: remote)
            await cloud.actor.update(model: .init(timestamp: 5))
            await cloud.load(container: container)
        }
        
        waitForExpectations(timeout: 0.5)
    }
}
