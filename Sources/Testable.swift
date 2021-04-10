import Foundation

struct Testable: Repo {
    typealias A = Archive
    static let memory = Memory<Self>()
    static let file = URL(string: "")!
    static let container = ""
    static let prefix = ""
    
    struct Archive: Archivable, Dateable {
        static func < (lhs: Archive, rhs: Archive) -> Bool { false }
        let date = Date()
        let data = Data()
        init(data: inout Data) { }
    }
}
