import XCTest
@testable import Archivable

final class WrapperTests: XCTestCase {
    func testUnwrap() async {
        let a2 = A2()
        let wrapper = await Wrapper<A2>(archive: a2)
        let loaded = await Wrapper<A2>(data: wrapper.compressed)
        let unwrapped = await loaded.archive
        XCTAssertEqual(a2.string, unwrapped.string)
    }
    
    func testMigration() async {
        let a1 = A1()
        let wrapper = await Wrapper<A2>(data: a1.compressed)
        let a2 = await wrapper.archive
        XCTAssertEqual(a1.string, a2.string)
    }
}

private struct A1: Arch {
    static var version = UInt8(2)
    
    var compressed: Data {
        get async {
            await
                .init()
                .adding(Self.version)
                .adding(UInt32.now)
                .adding(data)
                .compressed
        }
    }
    
    var string: String
    
    var data: Data {
        get async {
            .init()
            .adding(size: UInt32.self, string: string)
        }
    }
    
    init(version: UInt8, timestamp: UInt32, data: Data) async {
        var data = data
        string = data.string(size: UInt32.self)
    }
    
    init() {
        string = "hello world\nlorem ipsum"
    }
}

private struct A2: Arch {
    static var version = UInt8(6)
    
    var string: String
    
    var data: Data {
        get async {
            .init()
            .adding(size: UInt32.self, string: string)
        }
    }
    
    init(version: UInt8, timestamp: UInt32, data: Data) async {
        var data = data
        string = data.string(size: UInt32.self)
    }
    
    init() {
        string = "hello world\nlorem ipsum"
    }
}
