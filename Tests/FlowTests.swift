import XCTest
import Combine
import CloudKit
@testable import Archivable

final class FlowTests: XCTestCase {
    private var container: MockContainer!
    private var cloud: Cloud<Archive, MockContainer>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() async throws {
        container = .init(identifier: "")
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
        
        container.database
            .saved
            .sink {
                let query = $0 as? CKQuerySubscription
                XCTAssertNotNil(query)
                XCTAssertTrue(query!.predicate.predicateFormat.hasSuffix("; recordName=lorem, zoneID=_defaultZone:__defaultOwner__>"))
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.record.send(.init(recordName: "lorem"))
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testNotAvailable() {
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
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testAskRecordOnPull() {
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
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testAskRecordOnPush() {
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
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testAskRecordJustOnce() {
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
        cloud.pull.send()
        cloud.push.send()
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testPush() {
        let expect = expectation(description: "")
        expect.expectedFulfillmentCount = 2
        
        cloud.record.send(.init(recordName: "lorem"))
        
        container.database.pushed
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.push.send()
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testPull() {
        let expect = expectation(description: "")
        
        let remote = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let asset = CKAsset(fileURL: remote)
        let record = CKRecord(recordType: "lorem")
        record["payload"] = asset
        container.database.record = record
        
        Task {
            try! await Wrapper(archive: Archive(timestamp: 99, counter: 22)).compressed.write(to: remote)
            
            cloud
                .remote
                .sink {
                    XCTAssertEqual(99, $0?.timestamp)
                    expect.fulfill()
                }
                .store(in: &subs)
            
            cloud.record.send(.init(recordName: "lorem"))
            
            cloud.pull.send()
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testPullThrottle() {
        let expect = expectation(description: "")
        
        cloud.record.send(.init(recordName: "lorem"))
        
        container.database.pulled
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.pull.send()
        cloud.pull.send()
        cloud.pull.send()
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testFirstTime() {
        let expectCloud = expectation(description: "cloud")
        
        let expectStore = expectation(description: "store")
        expectStore.isInverted = true
        
        let expectPush = expectation(description: "push")
        expectPush.isInverted = true
        
        cloud
            .sink {
                XCTAssertEqual(0, $0.timestamp)
                expectCloud.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .store
            .sink { _ in
                expectStore.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .push
            .sink { _ in
                expectPush.fulfill()
            }
            .store(in: &subs)
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testRemoteSmallerThanLocal() {
        let expectCloud = expectation(description: "")
        expectCloud.isInverted = true
        
        let expectStore = expectation(description: "")
        expectStore.isInverted = true
        
        let expectPush = expectation(description: "")
        
        let expectResult = expectation(description: "")
        
        Task {
            await cloud.actor.update(model: .init(timestamp: 5))
        }
        
        cloud
            .dropFirst()
            .sink { _ in
                expectCloud.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .store
            .sink { _ in
                expectStore.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .push
            .sink {
                expectPush.fulfill()
            }
            .store(in: &subs)
        
        Task {
            await cloud.remote.send(Wrapper(archive: Archive(timestamp: 2)))
            let result = await cloud.actor.model.timestamp
            XCTAssertEqual(5, result)
            expectResult.fulfill()
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testRemoteSameAsLocal() {
        let expectCloud = expectation(description: "")
        expectCloud.isInverted = true
        
        let expectStore = expectation(description: "")
        expectStore.isInverted = true
        
        let expectPush = expectation(description: "")
        expectPush.isInverted = true
        
        let expectResult = expectation(description: "")
        
        Task {
            await cloud.actor.update(model: .init(timestamp: 5, counter: 3))
        }
        
        cloud
            .dropFirst()
            .sink { _ in
                expectCloud.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .store
            .sink { _ in
                expectStore.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .push
            .sink {
                expectPush.fulfill()
            }
            .store(in: &subs)
        
        Task {
            await cloud.remote.send(Wrapper(archive: Archive(timestamp: 5, counter: 4)))
            
            let result = await cloud.actor.model
            XCTAssertEqual(5, result.timestamp)
            XCTAssertEqual(3, result.counter)
            
            expectResult.fulfill()
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testNoLocalButRemote() {
        let expectCloud = expectation(description: "cloud")
        
        let expectStore = expectation(description: "store")

        let expectPush = expectation(description: "push")
        expectPush.isInverted = true
        
        cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(3, $0.timestamp)
                expectCloud.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .store
            .sink {
                XCTAssertEqual(3, $0.0.timestamp)

                Task {
                    let result = await self.cloud.actor.model.timestamp
                    XCTAssertEqual(3, result)
                    expectStore.fulfill()
                }
            }
            .store(in: &subs)

        cloud
            .push
            .sink {
                expectPush.fulfill()
            }
            .store(in: &subs)
        
        Task {
            await cloud.remote.send(Wrapper(archive: Archive(timestamp: 3)))
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testLocalSmallerThanRemote() {
        let expectCloud = expectation(description: "cloud")
        
        let expectStore = expectation(description: "store")
        
        let expectPush = expectation(description: "push")
        expectPush.isInverted = true
        
        Task {
            await cloud.actor.update(model: .init(timestamp: 2))
        }
        
        cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(3, $0.timestamp)
                expectCloud.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .store
            .sink {
                XCTAssertEqual(3, $0.0.timestamp)
                
                Task {
                    let result = await self.cloud.actor.model.timestamp
                    XCTAssertEqual(3, result)
                    expectStore.fulfill()
                }
            }
            .store(in: &subs)
        
        cloud
            .push
            .sink {
                expectPush.fulfill()
            }
            .store(in: &subs)
        
        Task {
            await cloud.remote.send(Wrapper(archive: Archive(timestamp: 3)))
        }
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testNoRemote() {
        let expectCloud = expectation(description: "cloud")
        expectCloud.isInverted = true
        
        let expectStore = expectation(description: "store")
        expectStore.isInverted = true
        
        let expectPush = expectation(description: "push")
        
        cloud
            .dropFirst()
            .sink { _ in
                expectCloud.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .store
            .sink { _ in
                expectStore.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .push
            .sink {
                expectPush.fulfill()
            }
            .store(in: &subs)
        
        cloud.record.send(.init(recordName: "lorem"))
        cloud.pull.send()
        
        waitForExpectations(timeout: 0.5)
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
        
        waitForExpectations(timeout: 0.5)
    }
    
    func testStoreNoPush() {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        Task {
            await cloud.remote.send(Wrapper(archive: Archive(timestamp: 3)))
        }
        
        cloud
            .push
            .sink {
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.store.send((.init(timestamp: 1), false))
        
        waitForExpectations(timeout: 0.5)
    }
}
