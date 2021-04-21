import Foundation

extension Data {
    public var compressed: Self {
        try! (self as NSData).compressed(using: .lzfse) as Self
    }
    
    public func mutating<M>(transform: (inout Self) -> M) -> M {
        var mutating = self
        return transform(&mutating)
    }
    
    public mutating func decompress() {
        self = try! (self as NSData).decompressed(using: .lzfse) as Self
    }
    
    public mutating func string() -> String {
        let size = Int(uInt16())
        let result = String(decoding: subdata(in: 0 ..< size), as: UTF8.self)
        self = removing(size)
        return result
    }
    
    public mutating func bool() -> Bool {
        removeFirst() == 1
    }
    
    public mutating func uInt16() -> UInt16 {
        let result = withUnsafeBytes {
            $0.baseAddress!.bindMemory(to: UInt16.self, capacity: 1)[0]
        }
        self = removing(2)
        return result
    }
    
    public mutating func uInt32() -> UInt32 {
        let result = withUnsafeBytes {
            $0.baseAddress!.bindMemory(to: UInt32.self, capacity: 1)[0]
        }
        self = removing(4)
        return result
    }
    
    public mutating func uInt64() -> UInt64 {
        let result = withUnsafeBytes {
            $0.baseAddress!.bindMemory(to: UInt64.self, capacity: 1)[0]
        }
        self = removing(8)
        return result
    }
    
    public func adding(_ data: Self) -> Self {
        self + data
    }
    
    public func adding(_ collection: [Self.Element]) -> Self {
        self + collection
    }
    
    public func adding(_ string: String) -> Self {
        {
            adding(UInt16($0.count)) + $0
        } (Data(string.utf8))
    }
    
    public func adding(_ bool: Bool) -> Self {
        self + [bool ? 1 : 0]
    }
    
    public func adding(_ number: UInt8) -> Self {
        self + [number]
    }
    
    public func adding(_ number: UInt16) -> Self {
        self + Swift.withUnsafeBytes(of: number) {
            .init(bytes: $0.bindMemory(to: UInt8.self).baseAddress!, count: 2)
        }
    }
    
    public func adding(_ number: UInt32) -> Self {
        self + Swift.withUnsafeBytes(of: number) {
            .init(bytes: $0.bindMemory(to: UInt8.self).baseAddress!, count: 4)
        }
    }
    
    public func adding(_ number: UInt64) -> Self {
        self + Swift.withUnsafeBytes(of: number) {
            .init(bytes: $0.bindMemory(to: UInt8.self).baseAddress!, count: 8)
        }
    }
    
    private mutating func removing(_ amount: Int) -> Self {
        count > amount ? advanced(by: amount) : .init()
    }
}
