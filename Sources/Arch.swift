import Foundation

public protocol Arch: Storable, Comparable {
    static var new: Self { get }
    var timestamp: UInt32 { get set }
}

extension Arch {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
