import Foundation

public protocol Arch {
    static var version: UInt8 { get }
    
    var data: Data { get async }
    var timestamp: UInt32 { get }
    
    init()
    init(version: UInt8, timestamp: UInt32, data: Data) async
}

extension Arch {
    public static var version: UInt8 {
        .init()
    }
}
