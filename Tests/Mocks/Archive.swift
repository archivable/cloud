import Foundation
import Archivable

struct Archive: Arch {
    static var version = UInt8(128)
    static let new = Self()
    
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
    
    private init() {
        timestamp = 0
        counter = 0
    }
}
