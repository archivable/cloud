import XCTest
import Combine
@testable import Archivable

final class ActorTests: XCTestCase {
    private var actor: Actor!
    private var subs: Set<AnyCancellable>!
    
    override func setUp(completion: @escaping (Error?) -> Void) {
        Task {
            actor = await Actor()
            completion(nil)
        }
        subs = .init()
    }
    
    func testInit() async {
        let n = await actor.acted.value
        XCTAssertEqual(100, n)
    }
    
    func testStream() {
        let expect = expectation(description: "")
        
        Task {
            actor = await Actor()
            actor
                .stream
                .sink {
                    let n = $0.value
                    XCTAssertEqual(100, n)
                    expect.fulfill()
                }
                .store(in: &subs)
        }
        
        waitForExpectations(timeout: 1)
    }
}
