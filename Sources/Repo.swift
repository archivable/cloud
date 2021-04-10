import Foundation

public protocol Repo {
    associatedtype A : Archivable, Dateable
    static var memory: Memory<Self> { get }
    static var file: URL { get }
    static var container: String { get }
    static var prefix: String { get }
}
