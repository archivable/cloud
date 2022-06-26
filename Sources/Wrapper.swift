import Foundation

struct Wrapper<A>: Storable where A : Arch {
    let version: UInt8
    let timestamp: UInt32
    let data: Data
    
    var archive: A {
        get async {
            await .init(version: version,
                        timestamp: timestamp,
                        data: data.decompressed)
        }
    }
    
    var compressed: Data {
        get async {
            await
                .init()
                .adding(A.version)
                .adding(timestamp)
                .adding(data)
                .compressed
        }
    }
    
    init(data: inout Data) {
        
    }
    
    init(archive: A) async {
        version = A.version
        timestamp = .now
        await data = archive.data
    }
}

extension Wrapper {
    public static var version: UInt8 {
        .init()
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
