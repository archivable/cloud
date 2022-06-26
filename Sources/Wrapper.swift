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
        .init()
        .adding(A.version)
        .adding(timestamp)
        .adding(data)
    }
    
    init(data: Data) async {
        var data = data
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
        timestamp = archive.timestamp
        await data = archive.data.compressed
    }
}

extension Wrapper {
    public static var version: UInt8 {
        .init()
    }
}
