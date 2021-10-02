import Foundation

extension Data {
    public static func prototype<P>(url: URL) -> P? where P : Storable {
        (try? Data(contentsOf: url))?.prototype()
    }
    
    public var compressed: Self {
        get async {
            await Task
                .detached(priority: .utility) {
                    try! (self as NSData).compressed(using: .lzfse) as Self
                }
                .value
        }
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
    
    public mutating func number<I>() -> I where I : UnsignedInteger {
        let result = withUnsafeBytes {
            $0.baseAddress!.bindMemory(to: I.self, capacity: 1)[0]
        }
        self = removing(MemoryLayout<I>.size)
        return result
    }
    
    public func adding<P>(_ storable: P) -> Self where P : Storable {
        self + storable.data
    }
    
    public func adding<I, S>(size: I.Type, collection: [S]) -> Self where I : UnsignedInteger, S : Storable {
        adding(I(collection.count))
            .adding(collection.flatMap(\.data))
    }
    
    public func adding<I, J>(collection: I.Type, strings: J.Type, items: [String]) -> Self where I : UnsignedInteger, J : UnsignedInteger {
        items
            .reduce(adding(I(items.count))) {
                $0
                    .adding(size: strings, string: $1)
            }
    }
    
    public func adding(_ data: Self) -> Self {
        self + data
    }
    
    public func adding(_ collection: [Element]) -> Self {
        self + collection
    }
    
    public func wrapping<I>(size: I.Type, data: Data) -> Self where I : UnsignedInteger {
        adding(I(data.count)) + data
    }
    
    public func adding<I>(size: I.Type, string: String) -> Self where I : UnsignedInteger {
        wrapping(size: size, data: .init(string.utf8))
    }
    
    public func adding(_ date: Date) -> Self {
        adding(date.timestamp)
    }
    
    public func adding(_ uuid: UUID) -> Self {
        adding(size: UInt8.self, string: uuid.uuidString)
    }
    
    public func adding(_ bool: Bool) -> Self {
        self + [bool ? 1 : 0]
    }
    
    public func adding<I>(_ number: I) -> Self where I : UnsignedInteger {
        self + Swift.withUnsafeBytes(of: number) {
            .init(bytes: $0.bindMemory(to: UInt8.self).baseAddress!, count: MemoryLayout<I>.size)
        }
    }
    
    private mutating func removing(_ amount: Int) -> Self {
        count > amount ? advanced(by: amount) : .init()
    }
}
