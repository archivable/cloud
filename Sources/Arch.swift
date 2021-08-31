import Foundation

public protocol Arch: Comparable {
    static var new: Self { get }
    static func prototype(data: Data) async -> Self
    
    var data: Data { get async }
    var timestamp: UInt32 { get set }
    
    init(timestamp: UInt32, data: inout Data) async
}

extension Arch {
    var compressed: Data {
        get async {
            await data
                .adding(timestamp)
                .compressed
        }
    }
    
    public static func prototype(data: Data) async -> Self {
        var data = await data
            .decompress
        return await .init(timestamp: data.uInt32(), data: &data)
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
