import Foundation
import Archivable

struct ArchiveMock: Arch {
    static let new = Self()
    var timestamp: UInt32
    var counter = 0
    
    var data: Data {
        Data()
            .adding(timestamp)
    }
    
    public init(data: inout Data) {
        timestamp = Date().timestamp
    }
    
    private init() {
        timestamp = 0
    }
}
