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
    public func mutating(transform: @escaping (inout C.A) -> Void) {
        queue.async {
            var archive = self.archive.value
            transform(&archive)
            if archive != self.archive.value {
                archive.date = .init()
                save.send(archive)
            }
        }
    }
}
