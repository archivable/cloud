import Foundation
import Archivable

struct Archive: Arch {
    var counter: Int
    var timestamp: UInt32
    
    var data: Data {
        get async {
            .init()
                .adding(UInt8(counter))
        }
    }
    
    init(version: UInt8, timestamp: UInt32, data: Data) async {
        var data = data
        self.timestamp = timestamp
        counter = .init(data.removeFirst())
    }
    
    init() {
        self.init(timestamp: 0, counter: 0)
    }
    
    init(timestamp: UInt32 = 0, counter: Int = 0) {
        self.timestamp = timestamp
        self.counter = counter
    }
}
