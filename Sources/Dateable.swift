import Foundation

public protocol Archived: Archivable, Comparable {
    static var new: Self { get }
    var date: Date { get }
}
