import Foundation
import Combine
import Archivable

struct Repository: Controller {
    typealias A = Archive
    
    static let memory = Cloud<Self>()
    static let file = URL.manifest("")
    static let container = ""
    static let prefix = ""
}

struct Archive: Archived {
    static let new = Self()
    var date: Date
    
    var data: Data {
        Data()
            .adding(date)
    }
    
    public init(data: inout Data) {
        date = .init(timestamp: data.uInt32())
    }
    
    private init() {
        date = .init(timeIntervalSince1970: 0)
    }
}
