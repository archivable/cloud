import Foundation

public protocol Dateable: Comparable {
    var date: Date { get }
}
