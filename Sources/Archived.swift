import Foundation

public protocol Archived: Property, Comparable {
    static var new: Self { get }
    var date: Date { get set }
}

extension Archived {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.date < rhs.date
    }
}
