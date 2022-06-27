import Foundation

private let header = "wrapper"
private let firmware = UInt8()

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
        .adding(.init(header.utf8))
        .adding(firmware)
        .adding(A.version)
        .adding(timestamp)
        .adding(data)
    }
    
    init(data: Data) async {
        var data = data
        
        if data.count > 8,
           String(decoding: data.prefix(7), as: UTF8.self) == header,
           data[7] == firmware {
            
            data = data.dropFirst(8)
            version = data.removeFirst()
            timestamp = data.number()
            self.data = data
        } else if var data = try? await data.decompress {
            
            version = data.removeFirst()
            timestamp = data.number()
            self.data = await data.compressed
        } else {
            
            let archive = A()
            version = A.version
            timestamp = archive.timestamp
            self.data = await archive.data.compressed
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
