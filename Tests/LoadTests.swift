import XCTest
import Combine
@testable import Cloud

final class LoadTests: XCTestCase {
    private var container: MockContainer!
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() async throws {
        container = .init(identifier: "")
        cloud = .init()
        try? FileManager.default.removeItem(at: cloud.url)
        subs = []
        try await Wrapper(archive: Archive(timestamp: 1)).compressed.write(to: cloud.url)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cloud.url)
    }
    
    func testLoad() {
        let expectCloud = expectation(description: "cloud")
        
        let expectStore = expectation(description: "store")
        expectStore.isInverted = true
        
        let expectPush = expectation(description: "push")
        expectPush.isInverted = true

        cloud
            .dropFirst()
            .sink {
                XCTAssertEqual(1, $0.timestamp)
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
            await cloud.load(container: container)
        }
        
        waitForExpectations(timeout: 0.5)
    }
}
