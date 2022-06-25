import Foundation

public protocol Wrap {
    associatedtype A : Arch
    
    static var version: UInt8 { get }
    
    var timestamp: UInt32 { get }
    var raw: Data { get }
    var archive: A { get }
    
    init(timestamp: UInt32, raw: Data)
}

extension Wrap {
    public static var version: UInt8 {
        .init()
    }
    
    var compressed: Data {
        get async {
            await
                .init()
                .adding(Self.version)
                .adding(timestamp)
                .wrapping(size: UInt32.self, data: raw)
                .compressed
        }
    }
    
    init(data: Data) async {
        var data = await data
            .decompressed
        
        if Self.version == data.removeFirst() {
            self.init(timestamp: data.number(), raw: data.unwrap(size: UInt32.self))
        } else {
            self.init(timestamp: .now, raw: .init())
        }
    }
}
