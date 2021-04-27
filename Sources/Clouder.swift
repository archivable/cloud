import Foundation
import Combine

public protocol Clouder {
    associatedtype C : Controller
    var archive: CurrentValueSubject<C.A, Never> { get }
    var save: PassthroughSubject<C.A, Never> { get }
    var queue: DispatchQueue { get }
    
    init()
}

public extension Clouder {
    func save(_ archive: inout C.A) {
        archive.date = .init()
        save.send(archive)
    }
}
