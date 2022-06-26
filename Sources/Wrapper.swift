import Foundation

struct Wrapper<A> where A : Arch {
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
                .adding(UInt32.now)
                .adding(data)
                .compressed
        }
    }
    
    init(data: inout Data) async {
        if A.version > 2 {
            version = data.removeFirst()
            timestamp = data.number()
            self.data = data
        } else {
            var data = await data.decompressed
            version = data.removeFirst()
            timestamp = data.number()
            self.data = await data.compressed
        }
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
}
