import XCTest
import Combine
@testable import Archivable

final class ActorTests: XCTestCase {
    private var subs: Set<AnyCancellable>!
    
    override func setUp() {
        subs = .init()
    }
    
    func testInit() async {
        let act = await Actor()
        let n = await act.acted.value
        XCTAssertEqual(100, n)
    }
    
    func testStream() {
        let expect = expectation(description: "")
        
        Task {
            let act = await Actor()

            act
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
