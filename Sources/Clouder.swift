import Foundation
import Combine

public protocol Clouder {
    associatedtype C : Controller
    var archive: CurrentValueSubject<C.A, Never> { get }
    var save: PassthroughSubject<C.A, Never> { get }
    var queue: DispatchQueue { get }
    
    init()
}

extension Clouder {
    public func save(_ archive: inout C.A) {
        archive.date = .init()
        save.send(archive)
    }
    
    public func mutate(transform: @escaping (inout C.A) -> Void) {
        queue.async {
            var archive = archive.value
            transform(&archive)
        }
    }
}
