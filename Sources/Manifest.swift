import Foundation

public protocol Manifest {
    associatedtype A : Archivable, Dateable
    static var file: URL { get }
    static var container: String { get }
    static var prefix: String { get }
}


