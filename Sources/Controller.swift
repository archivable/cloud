import Foundation
import Combine

public protocol Controller {
    associatedtype A : Archived
    static var memory: Memory<Self> { get }
    static var file: URL { get }
    static var container: String { get }
    static var prefix: String { get }
    static var override: PassthroughSubject<A, Never>? { get }
}

extension Controller {
    public static func save(_ archive: A) {
        guard override == nil else {
            override!.send(archive)
            return
        }
        memory.save.send(archive)
    }
}
