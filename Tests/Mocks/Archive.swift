import Foundation
import Archivable

struct Archive: Arch {
    static let new = Self()
    var counter: Int
    var timestamp: UInt32
    
    var data: Data {
        get async {
            .init()
                .adding(timestamp)
                .adding(UInt8(counter))
        }
    }
    
    init(timestamp: UInt32, data: inout Data) async {
        self.timestamp = timestamp
        counter = .init(data.removeFirst())
    }
    
    private init() {
        timestamp = 0
        counter = 0
    }
}
