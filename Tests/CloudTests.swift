import XCTest
import Combine
@testable import Archivable

final class CloudTests: XCTestCase {
    private var cloud: Cloud<ArchiveMock>!
    private var subs = Set<AnyCancellable>()
    
    override func setUp() {
        cloud = .init(manifest: nil)
    }
    
    func testMutateAndArchive() {
        let expect = expectation(description: "")
        let date = Date()
        cloud
            .archive
            .dropFirst()
            .sink {
                XCTAssertTrue(Thread.current.isMainThread)
                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .mutating {
                $0.timestamp = 10
            }
        
        waitForExpectations(timeout: 1)
    }
    
    func testMutateAndSave() {
        let expect = expectation(description: "")
        let date = Date()
        cloud
            .save
            .sink {
                XCTAssertGreaterThanOrEqual($0.timestamp, date.timestamp)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .mutating {
                $0.timestamp = 10
            }
        
        waitForExpectations(timeout: 1)
    }
    
    func testMutateDontSave() {
        cloud
            .save
            .sink { _ in
                XCTFail()
            }
            .store(in: &subs)
        
        cloud.mutating { _ in }
    }
    
    func testReceipt() {
        let expect = expectation(description: "")
        cloud.receipt {
            XCTAssertTrue($0)
            expect.fulfill()
        }
        
        cloud
            .mutating {
                $0.timestamp = 10
            }
        
        waitForExpectations(timeout: 1)
    }
    
    func testConsecutiveMutations() {
        let expect = expectation(description: "")
        expect.expectedFulfillmentCount = 2
        
        cloud
            .archive
            .dropFirst()
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .mutating {
                $0.counter += 1
            }
        
        cloud
            .mutating {
                $0.counter += 1
            }
        
        waitForExpectations(timeout: 1) { _ in
            XCTAssertEqual(2, self.cloud.archive.value.counter)
        }
    }
    
    func testCompletion() {
        let expect = expectation(description: "")
        
        cloud.mutating {
            $0.counter += 1
        } completion: {
            XCTAssertEqual(1, self.cloud.archive.value.counter)
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testCompletionVoid() {
        let expect = expectation(description: "")
        
        cloud.mutating {
            $0.counter += 1
            $0.counter += 2
        } completion: {
            XCTAssertEqual(3, self.cloud.archive.value.counter)
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testEphemeral() {
        let expect = expectation(description: "")
        cloud
            .archive
            .dropFirst()
            .sink {
                XCTAssertTrue(Thread.current.isMainThread)
                XCTAssertEqual(1, $0.counter)
                expect.fulfill()
            }
            .store(in: &subs)
        
        cloud
            .save
            .sink { _ in
                XCTFail()
            }
            .store(in: &subs)
        
        cloud
            .ephemeral {
                $0.counter = 1
            }
        
        waitForExpectations(timeout: 1)
    }
    
    func testTransform() {
        let expect = expectation(description: "")
        cloud
            .archive
            .dropFirst()
            .sink { _ in
                XCTFail()
            }
            .store(in: &subs)
        
        cloud
            .save
            .sink { _ in
                XCTFail()
            }
            .store(in: &subs)
        
        cloud
            .transform {
                XCTAssertFalse(Thread.current.isMainThread)
                return $0.counter + 1
            } completion: { (result: Int) in
                XCTAssertTrue(Thread.current.isMainThread)
                XCTAssertEqual(1, result)
                expect.fulfill()
            }
        
        waitForExpectations(timeout: 1)
    }
}
