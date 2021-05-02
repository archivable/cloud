import Foundation
import Archivable

struct ArchiveMock: Archived {
    static let new = Self()
    var date: Date
    var counter = 0
    
    var data: Data {
        Data()
            .adding(date)
    }
    
    public init(data: inout Data) {
        date = .init()
    }
    
    private init() {
        date = .init(timeIntervalSince1970: 0)
    }
}
