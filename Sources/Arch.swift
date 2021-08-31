import Foundation

public protocol Arch: Comparable {
    static var new: Self { get }
    static var version: UInt8 { get }
    
    var data: Data { get async }
    var timestamp: UInt32 { get set }
    
    init(version: UInt8, timestamp: UInt32, data: inout Data) async
}

extension Arch {
    var compressed: Data {
        get async {
            await
                .init()
                .adding(Self.version)
                .adding(timestamp)
                .adding(data)
                .compressed
        }
    }
    
    static func prototype(data: Data) async -> Self {
        var data = await data
            .decompress
        
        return await .init(version: data.removeFirst(), timestamp: data.uInt32(), data: &data)
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
