import Foundation

public struct Testable: Repo {
    public typealias A = Archive
    public static let memory = Memory<Self>()
    public static let file = URL(string: "")!
    public static let container = ""
    public static let prefix = ""
}

public struct Archive: Archivable, Dateable {
    public static func < (lhs: Archive, rhs: Archive) -> Bool { false }
    public let date = Date()
    public let data = Data()
    public init(data: inout Data) { }
}
