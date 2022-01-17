import XCTest
import Combine
@testable import Archivable

final class FlowTests: XCTestCase {
    private var cloud: Cloud<Archive>!
    private var subs: Set<AnyCancellable>!
    
    override func setUp() {
        cloud = .init()
        subs = []
    }
    
    func testPersist() {
        
    }
}
