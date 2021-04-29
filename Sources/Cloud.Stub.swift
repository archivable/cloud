import CloudKit
import Combine

extension Cloud where C : Controller {
    public struct Stub: Clouder {
        public let archive = CurrentValueSubject<C.A, Never>(.new)
        public let save = PassthroughSubject<C.A, Never>()
        public let queue = DispatchQueue(label: "", qos: .utility)
        
        public init() { }
    }
}
