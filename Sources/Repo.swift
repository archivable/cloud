import Foundation
import Combine

public protocol Repo {
    associatedtype A : Archivable, Dateable
    static var memory: Memory<Self> { get }
    static var file: URL { get }
    static var container: String { get }
    static var prefix: String { get }
    static var override: PassthroughSubject<A, Never>? { get }
}

extension Repo {
    public static func save(_ archive: A) {
        guard override == nil else {
            override!.send(archive)
            return
        }
        memory.save.send(archive)
    }
}
