import XCTest
import Archivable

final class DataTests: XCTestCase {
    func testString() {
        let string = "hello world"
        XCTAssertEqual(string, Data().adding(size: UInt64.self, string: string).mutating { $0.string(size: UInt64.self) })
        XCTAssertEqual(string, Data().adding(size: UInt8.self, string: string).mutating { $0.string(size: UInt8.self) })
    }
    
    func testPrimitives() {
        Data()
            .adding(UInt8(1))
            .adding(UInt16(2))
            .adding(UInt32(3))
            .adding(UInt64(4))
            .adding(true)
            .adding(false)
            .adding(Date(timeIntervalSince1970: 10))
            .adding([Date(timeIntervalSince1970: 10), .init(timeIntervalSince1970: 20)]
                        .flatMap(\.data))
            .adding(UUID())
            .wrapping(size: UInt8.self, data: Data([1,2,3,4,5,6]))
            .mutating {
                XCTAssertEqual(1, $0.number() as UInt8)
                XCTAssertEqual(2, $0.number() as UInt16)
                XCTAssertEqual(3, $0.number() as UInt32)
                XCTAssertEqual(4, $0.number() as UInt64)
                XCTAssertEqual(true, $0.bool())
                XCTAssertEqual(false, $0.bool())
                XCTAssertEqual(Date(timeIntervalSince1970: 10).timestamp, $0.date().timestamp)
                XCTAssertEqual(Date(timeIntervalSince1970: 10).timestamp, $0.date().timestamp)
                XCTAssertEqual(Date(timeIntervalSince1970: 20).timestamp, $0.date().timestamp)
                XCTAssertNotNil($0.uuid())
                XCTAssertEqual(Data([1,2,3,4,5,6]), $0.unwrap(size: UInt8.self))
            }
    }
    
    func testPrototype() {
        struct A: Storable, Equatable {
            let number: Int
            
            var data: Data {
                .init()
                    .adding(UInt16(number))
            }
            
            init(data: inout Data) {
                number = .init(data.number() as UInt16)
            }
            
            init(number: Int) {
                self.number = number
            }
        }
        
        XCTAssertEqual(A(number: 5), Data()
                        .adding(A(number: 5))
                        .prototype())
        
        XCTAssertEqual(5, Data()
                        .adding(A(number: 5))
                        .prototype(A.self)
                        .number)
    }
    
    func testStorable() {
        struct A: Storable, Equatable {
            let number: Int
            
            var data: Data {
                .init()
                    .adding(UInt16(number))
            }
            
            init(number: Int) {
                self.number = number
            }
            
            init(data: inout Data) {
                number = .init(data.number() as UInt16)
            }
        }
        
        var data = Data()
            .adding(size: UInt64.self, collection: [A(number: 3), .init(number: 2)])

        XCTAssertEqual(2, data.number() as UInt64)
        XCTAssertEqual(A(number: 3), data.storable())
        XCTAssertEqual(A(number: 2), data.storable())
    }
    
    func testSequence() {
        struct A: Storable, Equatable {
            let number: Int
            
            var data: Data {
                .init()
                    .adding(UInt16(number))
            }
            
            init(number: Int) {
                self.number = number
            }
            
            init(data: inout Data) {
                number = .init(data.number() as UInt16)
            }
        }
        
        let data = Data()
            .adding(size: UInt64.self, collection: [A(number: 3), .init(number: 2)])
        var parse = data
        XCTAssertEqual([A(number: 3), .init(number: 2)], parse.collection(size: UInt64.self))
        
        parse = data
        XCTAssertEqual(2, parse.number() as UInt64)
        XCTAssertEqual(A(number: 3), parse.subdata(in: 0 ..< 2).prototype())
        XCTAssertEqual(A(number: 2), parse.subdata(in: 2 ..< 4).prototype())
    }
    
    func testNumber() {
        XCTAssertEqual(1, Data().adding(UInt8(100)).count)
    }
    
    func testLongString() {
        let string = "data:image/jpeg;base64,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"
        
        let a = Data().wrapping(size: UInt16.self, data: .init(string.utf8))
        let b = Data().adding(UInt16(string.count)).adding(.init(string.utf8))
        XCTAssertEqual(a, b)
    }
}
