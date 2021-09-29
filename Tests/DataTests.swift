import XCTest
import Archivable

final class DataTests: XCTestCase {
    func testString() {
        let string = "hello world"
        XCTAssertEqual(string, Data().adding(UInt64.self, string: string).mutating { $0.string(UInt64.self) })
        XCTAssertEqual(string, Data().adding(UInt8.self, string: string).mutating { $0.string(UInt8.self) })
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
            .wrapping(UInt8.self, data: Data([1,2,3,4,5,6]))
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
                XCTAssertEqual(Data([1,2,3,4,5,6]), $0.unwrap(UInt8.self))
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
            .adding(UInt64.self, collection: [A(number: 3), .init(number: 2)])

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
            .adding(UInt64.self, collection: [A(number: 3), .init(number: 2)])
        var parse = data
        XCTAssertEqual([A(number: 3), .init(number: 2)], parse.sequence(UInt64.self))
        
        parse = data
        XCTAssertEqual(2, parse.number() as UInt64)
        XCTAssertEqual(A(number: 3), parse.subdata(in: 0 ..< 2).prototype())
        XCTAssertEqual(A(number: 2), parse.subdata(in: 2 ..< 4).prototype())
    }
}
