import Foundation

extension Data {
    public static func prototype<P>(url: URL) -> P? where P : Storable {
        (try? Data(contentsOf: url))?.prototype()
    }
    
    public var decompressed: Self {
        get async {
            await Task
                .detached(priority: .utility) {
                    try! (self as NSData).decompressed(using: .lzfse) as Self
                }
                .value
        }
    }
    
    public var decompress: Self {
        get async throws {
            try await Task
                .detached(priority: .utility) {
                    try (self as NSData).decompressed(using: .lzfse) as Self
                }
                .value
        }
    }
    
    public func prototype<P>() -> P where P : Storable {
        var mutating = self
        return .init(data: &mutating)
    }
    
    public func prototype<P>(_ type: P.Type) -> P where P : Storable {
        prototype()
    }
    
    public mutating func storable<S>() -> S where S : Storable {
        .init(data: &self)
    }
    
    public func mutating<M>(transform: (inout Self) -> M) -> M {
        var mutating = self
        return transform(&mutating)
    }
    
    public mutating func collection<I, S>(size: I.Type) -> [S] where I : UnsignedInteger, S : Storable {
        (0 ..< .init(number() as I))
            .map { _ in
                .init(data: &self)
            }
    }
    
    public mutating func collection<I, N>(size: I.Type) -> [N] where I : UnsignedInteger, N : Numeric {
        (0 ..< .init(number() as I))
            .map { _ in
                number()
            }
    }
    
    public mutating func items<I, J>(collection: I.Type, strings: J.Type) -> [String] where I : UnsignedInteger, J : UnsignedInteger {
        (0 ..< .init(number() as I))
            .map { _ in
                string(size: strings)
            }
    }
    
    public mutating func unwrap<I>(size: I.Type) -> Data where I : UnsignedInteger {
        let size = Int(number() as I)
        let result = subdata(in: 0 ..< size)
        self = removing(size)
        return result
    }
    
    public mutating func string<I>(size: I.Type) -> String where I : UnsignedInteger {
        .init(decoding: unwrap(size: size), as: UTF8.self)
    }
    
    public mutating func date() -> Date {
        .init(timestamp: number() as UInt32)
    }
    
    public mutating func uuid() -> UUID {
        UUID(uuidString: string(size: UInt8.self))!
    }
    
    public mutating func bool() -> Bool {
        removeFirst() == 1
    }
    
    public mutating func number<I>() -> I where I : Numeric {
        let result = withUnsafeBytes {
            $0.baseAddress!.bindMemory(to: I.self, capacity: 1)[0]
        }
        self = removing(MemoryLayout<I>.size)
        return result
    }
    
    private mutating func removing(_ amount: Int) -> Self {
        count > amount ? advanced(by: amount) : .init()
    }
}
