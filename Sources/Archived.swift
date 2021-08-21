import Foundation

public protocol Archived: Property, Comparable {
    static var new: Self { get }
    var timestamp: UInt32 { get set }
}

extension Archived {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
