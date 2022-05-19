import Foundation

extension Data {
    public var compressed: Self {
        get async {
            await Task
                .detached(priority: .utility) {
                    try! (self as NSData).compressed(using: .lzfse) as Self
                }
                .value
        }
    }
    
    public func adding<P>(optional: P?) -> Self where P : Storable {
        optional
            .map {
                adding($0)
            }
        ?? self
    }
    
    public func adding<P>(_ storable: P) -> Self where P : Storable {
        self + storable.data
    }
    
    public func adding<I, C>(size: I.Type, collection: C) -> Self where C : Collection, C.Element : Storable, I : UnsignedInteger {
        adding(I(collection.count))
            .adding(collection.flatMap(\.data))
    }
    
    public func adding<I, C>(size: I.Type, collection: C) -> Self where C : Collection, C.Element : Numeric, I : UnsignedInteger {
        collection
            .reduce(adding(I(collection.count))) {
                $0
                    .adding($1)
            }
    }
    
    public func adding<I, J, C>(collection: I.Type, strings: J.Type, items: C) -> Self where C : Collection, C.Element == String, I : UnsignedInteger, J : UnsignedInteger {
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
    
    public func adding<I>(_ number: I) -> Self where I : Numeric {
        self + Swift.withUnsafeBytes(of: number) {
            .init(bytes: $0.bindMemory(to: UInt8.self).baseAddress!, count: MemoryLayout<I>.size)
        }
    }
}
