import CloudKit
import Combine

extension Cloud {
    public struct Stub<C>: Clouder where C : Controller {
        public let archive = CurrentValueSubject<C.A, Never>(.new)
        public let save = PassthroughSubject<C.A, Never>()
        public let queue = DispatchQueue(label: "", qos: .utility)
        
        public init() { }
    }
}
