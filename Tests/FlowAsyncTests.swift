import XCTest
import Combine
import CloudKit
@testable import Archivable

final class FlowAsyncTests: XCTestCase {
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
        
        await cloud.upate(model: .init(timestamp: 3))
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cloud.url)
    }
    
    func testLocalMergeRemote_Model() async {
        let expect = expectation(description: "")
        expect.isInverted = true
        
        cloud
            .dropFirst()
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud.remote.send(.init(timestamp: 2))
        
        let current = await cloud.model.timestamp
        XCTAssertEqual(3, current)
        
        await waitForExpectations(timeout: 1)
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
